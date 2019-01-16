defmodule Parse.Alerts do
  @moduledoc """
  Parse the Enhanced JSON feed from IBI.

  The enhanced feed is a JSON representation of the Protobuf data, with additional fields to represent data that extends
  the basic field set.
  """

  use Timex

  alias Model.Alert

  import :binary, only: [copy: 1]

  @behaviour Parse

  @spec parse(String.t()) :: [Alert.t()]
  def parse(body) do
    body
    |> Jason.decode!()
    |> parse_json()
  end

  @spec parse_json(%{optional(String.t()) => any}) :: [Model.Alert.t()]
  def parse_json(json_map) do
    for alert <- alert_json(json_map), active?(alert) do
      alert
      |> parse_alert()
      |> cleanup_description
    end
  end

  defp alert_json(%{"entity" => entities}) do
    for %{"id" => id, "alert" => alert} <- entities do
      Map.put(alert, "id", id)
    end
  end

  defp alert_json(%{"alerts" => alerts}) do
    alerts
  end

  def active?(%{"active_period" => _, "informed_entity" => [_ | _]}), do: true
  def active?(%{}), do: false

  def parse_alert(alert) do
    %Alert{
      id: Map.get(alert, "id"),
      effect: alert |> Map.get("effect_detail") |> copy,
      cause: cause(alert),
      header: alert |> Map.get("header_text") |> translated_text,
      short_header: alert |> Map.get("short_header_text") |> translated_text,
      description: alert |> Map.get("description_text") |> translated_text,
      banner: alert |> Map.get("banner_text") |> translated_text(default: nil),
      severity: Map.get(alert, "severity"),
      created_at: alert |> Map.get("created_timestamp") |> unix_timestamp,
      updated_at: alert |> Map.get("last_modified_timestamp") |> unix_timestamp,
      active_period: alert |> Map.get("active_period") |> Enum.map(&active_period/1),
      informed_entity: alert |> Map.get("informed_entity") |> Enum.map(&informed_entity/1),
      service_effect: alert |> Map.get("service_effect_text") |> translated_text,
      timeframe: alert |> Map.get("timeframe_text") |> translated_text(default: nil),
      lifecycle: alert |> Map.get("alert_lifecycle") |> lifecycle,
      url: alert |> Map.get("url") |> translated_text(default: nil)
    }
  end

  defp cause(%{"cause_detail" => cause}) do
    copy(cause)
  end

  defp cause(%{"cause" => cause}) do
    copy(cause)
  end

  def lifecycle("ONGOING"), do: "ONGOING"
  def lifecycle("UPCOMING"), do: "UPCOMING"
  def lifecycle(<<"UPCOMING", _::binary-1, "ONGOING">>), do: "ONGOING_UPCOMING"
  def lifecycle(<<"ONGOING", _::binary-1, "UPCOMING">>), do: "ONGOING_UPCOMING"
  def lifecycle("NEW"), do: "NEW"
  def lifecycle(_), do: "UNKNOWN"

  defp translated_text(translations, opts \\ []) do
    opts =
      opts
      |> Map.new()
      |> Map.put_new(:default, "")

    do_translated_text(translations, opts)
  end

  defp do_translated_text([], %{default: default}) do
    default
  end

  defp do_translated_text(nil, %{default: default}) do
    default
  end

  defp do_translated_text(%{"translation" => translations}, opts) do
    do_translated_text(translations, opts)
  end

  defp do_translated_text([%{"language" => "en", "text" => text} | _], _) do
    copy(text)
  end

  defp do_translated_text([%{"translation" => %{"language" => "en", "text" => text}} | _], _) do
    copy(text)
  end

  defp do_translated_text([_wrong_language | rest], opts) do
    do_translated_text(rest, opts)
  end

  defp active_period(%{"start" => start, "end" => stop}) do
    {unix_timestamp(start), unix_timestamp(stop)}
  end

  defp active_period(%{"start" => start}) do
    {unix_timestamp(start), nil}
  end

  defp active_period(%{"end" => stop}) do
    {nil, unix_timestamp(stop)}
  end

  defp active_period(%{}) do
    {nil, nil}
  end

  defp activities(list) when is_list(list), do: Enum.map(list, &copy/1)

  defp informed_entity(json) do
    %{}
    |> build_informed_entity(json, ["activities"], :activities, &activities/1)
    |> build_informed_entity(json, ["direction_id"], :direction_id)
    |> build_informed_entity(json, ["facility_id"], :facility, &copy/1)
    |> build_informed_entity(json, ["route_id"], :route, &copy/1)
    |> build_informed_entity(json, ["route_type"], :route_type)
    |> build_informed_entity(json, ["stop_id"], :stop, &copy/1)
    |> build_informed_entity(json, ["trip", "direction_id"], :direction_id)
    |> build_informed_entity(json, ["trip", "trip_id"], :trip, &copy/1)
  end

  defp build_informed_entity(entity, json, access, entity_field, mapper \\ fn x -> x end) do
    case get_in(json, access) do
      nil ->
        entity

      value ->
        Map.put(entity, entity_field, mapper.(value))
    end
  end

  defp unix_timestamp(seconds_since_epoch) do
    seconds_since_epoch
    |> DateTime.from_unix!()
    |> Timex.to_datetime("America/New_York")
  end

  defp cleanup_description(%Alert{} = alert) do
    # strip the header from the description
    prefix = "#{alert.header}."

    description =
      alert.description
      |> String.replace_prefix(prefix, "")
      |> String.trim_leading()

    if description == "" do
      %{alert | description: nil}
    else
      %{alert | description: description}
    end
  end
end
