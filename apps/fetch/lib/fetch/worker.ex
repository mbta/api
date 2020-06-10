defmodule Fetch.Worker do
  @moduledoc """

  A worker for fetching a particular URL.  It can maintain a simple cache of
  the file on the filesystem if :cache_directory is passed in as an option.

  """
  use GenServer, restart: :temporary
  use Timex
  require Logger

  def start_link(parent_opts \\ [], url) do
    GenServer.start_link(__MODULE__, {url, parent_opts}, name: via_tuple(url))
  end

  def via_tuple(url) do
    {:via, Registry, {Fetch.Registry, url}}
  end

  def fetch_url(pid, opts) do
    opts = Keyword.put_new(opts, :timeout, 2500)

    timeout =
      opts
      |> Keyword.get(:timeout)
      |> max(2500)

    call_timeout = Keyword.get(opts, :call_timeout, timeout * 2)

    # we use 2*timeout to give the server some time after the HTTP request
    # times out, along with a minimum of 5 seconds.
    try do
      GenServer.call(pid, {:fetch_url, opts}, call_timeout)
    catch
      error ->
        {:error, error}

      :exit, {reason, _} ->
        {:error, reason}
    end
  end

  def init({url, parent_opts}) do
    {:ok, initial_state(url, parent_opts)}
  end

  def handle_call({:fetch_url, opts}, _from, %{url: url} = state) do
    opts =
      opts
      |> Keyword.put_new(:recv_timeout, opts[:timeout])
      |> Keyword.put_new(:hackney, pool: :fetch_pool)

    http_response = HTTPoison.get(url, state_headers(state), opts)

    response = reply(http_response, opts, state)

    {:reply, response, update_state(state, http_response), :hibernate}
  end

  def handle_info({:ssl_closed, _}, state) do
    # ignore spurious SSL closed message: https://github.com/benoitc/hackney/issues/464
    {:noreply, state}
  end

  def handle_info(message, state) do
    _ =
      Logger.warn(fn ->
        # no cover
        "unexpected message to Fetch.Worker[#{state.url}]: #{inspect(message)}"
      end)

    {:noreply, state}
  end

  defp initial_state(url, opts) do
    uri = URI.parse(url)

    cache_file =
      case opts |> Keyword.get(:cache_directory) do
        nil -> nil
        directiory -> directiory <> (uri.path |> Path.basename())
      end

    last_modified =
      with filename when is_binary(filename) <- cache_file,
           {:ok, stat} <- File.stat(filename),
           date = stat.ctime |> elem(0) |> Date.from_erl!(),
           {:ok, formatted} <- Timex.format(date, "{RFC1123}") do
        formatted
      else
        _ ->
          nil
      end

    %{
      url: url,
      cache_file: cache_file,
      etag: nil,
      last_modified: last_modified,
      hash: nil
    }
  end

  defp state_headers(%{etag: etag, last_modified: last_modified}) do
    headers = [
      {:"accept-encoding", "gzip"}
    ]

    headers =
      if etag do
        Keyword.put(headers, :"if-none-match", etag)
      else
        headers
      end

    headers =
      if last_modified != nil do
        Keyword.put(headers, :"if-modified-since", last_modified)
      else
        headers
      end

    headers
  end

  defp reply({:ok, %{status_code: 200, body: body} = response}, opts, %{hash: hash, url: url}) do
    cond do
      Keyword.get(opts, :require_body) ->
        decode_body(response)

      :erlang.phash2(body) == hash ->
        _ = Logger.debug(fn -> "#{url} received same content" end)
        :unmodified

      true ->
        decode_body(response)
    end
  end

  defp reply({:ok, %{status_code: 304}}, opts, %{cache_file: cache_file, url: url}) do
    if Keyword.get(opts, :require_body) do
      _ = Logger.debug(fn -> "#{url} received 304, sending cached file" end)
      File.read(cache_file)
    else
      _ = Logger.debug(fn -> "#{url} received 304" end)
      :unmodified
    end
  end

  defp reply({:ok, %{status_code: error} = response}, _, %{url: url})
       when error >= 400 and error < 600 do
    _ = Logger.error(fn -> "Error response when fetching #{url}: #{inspect(response)}" end)
    {:error, response}
  end

  defp reply(response, opts, %{url: url, cache_file: cache_file}) when cache_file != nil do
    logger = logger_with_level_for_error(response)

    _ =
      logger.(fn ->
        "Unknown response when fetching #{url}: #{inspect(response)}"
      end)

    if Keyword.get(opts, :require_body) do
      _ = Logger.debug(fn -> "...sending cached file anyways" end)
      File.read(cache_file)
    else
      :unmodified
    end
  end

  defp reply(response, _opts, %{url: url}) do
    logger = logger_with_level_for_error(response)

    _ =
      logger.(fn ->
        "Unknown response when fetching #{url}: #{inspect(response)}"
      end)

    case response do
      {:error, _} ->
        response

      _ ->
        {:error, response}
    end
  end

  defp decode_body(%{headers: headers, body: body}) do
    case read_header(headers, "content-encoding") do
      "gzip" ->
        {:ok, :zlib.gunzip(body)}

      nil ->
        {:ok, body}

      other ->
        {:error, {:invalid_encoding, other}}
    end
  end

  defp logger_with_level_for_error({:error, %HTTPoison.Error{reason: :timeout}}),
    do: &Logger.warn/1

  defp logger_with_level_for_error(_), do: &Logger.error/1

  defp update_state(
         %{cache_file: cache_file} = state,
         {:ok, %{status_code: 200, body: body, headers: headers}}
       ) do
    etag = read_header(headers, "etag")
    last_modified = read_header(headers, "last-modified")
    hash = :erlang.phash2(body)
    write_cache_file(cache_file, body)

    %{
      state
      | etag: etag || state[:etag],
        last_modified: last_modified || state[:last_modified],
        hash: hash
    }
  end

  defp update_state(state, _) do
    state
  end

  defp write_cache_file(cache_file, body) when is_binary(cache_file) do
    case File.write(cache_file, body) do
      :ok ->
        :ok

      {:error, posix} ->
        _ = Logger.warn("Error while writing #{cache_file}: #{inspect(posix)}")
        :ok
    end
  end

  defp write_cache_file(_, _), do: :ok

  @spec read_header([{String.t(), String.t()}], String.t()) :: String.t() | nil
  defp read_header(headers, name) do
    case Enum.find(headers, fn {header, _} ->
           String.downcase(header) == name
         end) do
      {_, value} -> value
      nil -> nil
    end
  end
end
