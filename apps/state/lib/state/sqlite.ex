defmodule State.Sqlite do
  @moduledoc false

  @name __MODULE__

  def start_link([]) do
    Exqlite.start_link(default_opts())
  end

  def child_spec([]) do
    {:ok, _} = Application.ensure_all_started(:db_connection)
    Exqlite.child_spec(default_opts())
  end

  def run(fun) do
    DBConnection.run(@name, fun)
  end

  def transaction(fun, opts \\ [])

  def transaction(fun, opts) when is_function(fun, 1) do
    transaction_opts = Keyword.take(opts, [:timeout])

    DBConnection.transaction(@name, fun, transaction_opts)
  end

  defdelegate query(conn, statement, params), to: Exqlite
  defdelegate prepare(conn, name, statement), to: Exqlite
  defdelegate execute(conn, query, params), to: Exqlite
  defdelegate close(conn, query), to: Exqlite

  defp default_opts(opts \\ [name: @name]) do
    priv_dir = :code.priv_dir(:state)

    Keyword.merge(
      [
        database: Path.join(priv_dir, "state.db"),
        journal_mode: :wal,
        cache_size: -64_000,
        temp_store: :memory,
        auto_vacuum: :incremental,
        foreign_keys: :off,
        pool: DBConnection.ConnectionPool,
        pool_size: 20,
        chunk_size: 100
      ],
      opts
    )
  end
end
