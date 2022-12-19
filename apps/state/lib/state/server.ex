defmodule State.Server do
  @moduledoc """
  Generates an Mnesia database for structs, indexed by specified struct fields.

  ## Example

  defmodule Example do
    use Recordable, [:id, :data, :other_key]
  end

  defmodule ExampleServer do
    use State.Server, indices: [:id, :other_key], recordable: Example
  end

  Then, clients can do:

  State.ExampleServer.new_state([<list of structs>])
  State.ExampleServer.by_id(id)
  State.ExampleServer.by_ids([<list of ids>])
  State.ExampleServer.by_other_key(key)
  State.ExampleServer.by_other_keys([<list of key>])

  ## Metadata

  When a new state is loaded, the server's last-updated timestamp in `State.Metadata` is set to
  the current datetime.

  ## Parsers

  Servers can specify a `parser` module that implements the `Parse` behaviour. If so, `new_state`
  accepts a string in addition to a list of structs, and strings will be passed through the parser
  module.

  ## Events

  An event is published using `Events` whenever a new state is loaded, including on startup. The
  event name is `{:new_state, server_module}` and the data is the new count of structs.

  Servers can specify a `fetched_filename` option. If so, the server subscribes to events named
  `{:fetch, fetched_filename}`, and calls `new_state` with the event data.

  ## Callbacks

  Server modules can override any of these callbacks:

  * `handle_new_state/1` — Called with the value passed to any `new_state` call; can be used to
      accept state values that are not strings or struct lists. Should call `super` with a string
      or struct list to perform the actual update.

  * `pre_insert_hook/1` — Called with each struct before inserting it into the table. Must return
      a list of structs to insert (one struct can be transformed into zero or multiple).

  * `post_commit_hook/0` — Called once after a new state has been committed, but before the
      `:new_state` event has been published. Servers can use this to e.g. update additional data
      that needs to remain consistent with the main table.

  * `post_load_hook/1` — Called with the list of structs to be returned whenever data is requested
      from the server, e.g. using `all` or `by_*` functions. Must return the list of structs to be
      returned to the caller. Allows filtering or transforming results on load.
  """
  @callback handle_new_state(binary | [struct]) :: :ok
  @callback post_commit_hook() :: :ok
  @callback post_load_hook([struct]) :: [struct] when struct: any
  @callback pre_insert_hook(struct) :: [struct] when struct: any
  @optional_callbacks [post_commit_hook: 0, post_load_hook: 1, pre_insert_hook: 1]

  require Logger

  import Events
  import State.Logger
  alias State.Sqlite, as: Sql

  defmacro __using__(opts) do
    indices = Keyword.fetch!(opts, :indices)
    hibernate? = Keyword.get(opts, :hibernate, true)

    recordable =
      case Keyword.fetch!(opts, :recordable) do
        {:__aliases__, _, module_parts} -> Module.concat(module_parts)
      end

    key_index = List.first(recordable.fields)

    quote do
      use Events.Server
      require Logger

      alias unquote(__MODULE__), as: Server
      alias unquote(opts[:recordable]), as: RECORDABLE

      @behaviour Server

      # Client functions

      @doc "Start the #{__MODULE__} server."
      def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

      @doc "Send a new state to the server."
      @spec new_state(any) :: :ok
      def new_state(state, timeout \\ 300_000),
        do: GenServer.call(__MODULE__, {:new_state, state}, timeout)

      @doc "Returns a timestamp of when the server was last updated with new data."
      @spec last_updated() :: DateTime.t() | nil
      def last_updated, do: GenServer.call(__MODULE__, :last_updated)

      @doc "Updates the server's metadata with when it was last updated."
      def update_metadata, do: GenServer.cast(__MODULE__, :update_metadata)

      @doc "Returns the number of elements in the server."
      @spec size() :: non_neg_integer
      def size, do: Server.size(__MODULE__)

      @doc "Returns all the #{__MODULE__} structs."
      @spec all(opts :: Keyword.t()) :: [RECORDABLE.t()]
      def all(opts \\ []), do: Server.all(__MODULE__, opts)

      @doc "Returns all the keys for #{__MODULE__}."
      @spec all_keys() :: [term]
      def all_keys, do: Server.all_keys(__MODULE__)

      @spec match(map, atom) :: [RECORDABLE.t()]
      @spec match(map, atom, opts :: Keyword.t()) :: [RECORDABLE.t()]
      def match(matcher, index, opts \\ []), do: Server.match(__MODULE__, matcher, index, opts)

      @spec select([map]) :: [RECORDABLE.t()]
      @spec select([map], atom | nil) :: [RECORDABLE.t()]
      def select(matchers, index \\ nil), do: Server.select(__MODULE__, matchers, index)

      @spec select_limit([map], pos_integer) :: [RECORDABLE.t()]
      def select_limit(matchers, num_objects),
        do: Server.select_limit(__MODULE__, matchers, num_objects)

      # define a `by_<index>` and `by_<index>s` method for each indexed field
      unquote(State.Server.def_by_indices(indices, key_index: key_index))

      # Metadata functions

      @doc """
      The _single_ filename that must be fetched to generate a new state.  If there is no file
      name OR there are multiple file names, this will be `nil`.
      """
      @spec fetched_filename :: String.t() | nil
      def fetched_filename, do: unquote(opts[:fetched_filename])

      @doc """
      indices in the `:mnesia` table where state is stored
      """
      @spec indices :: [atom]
      def indices, do: unquote(indices)

      @doc """
      The index for the primary key
      """
      @spec key_index :: atom
      def key_index, do: List.first(recordable().fields())

      @doc """
      Module that defines struct used in state list and implements `Recordable` behaviour.
      """
      @spec recordable :: module
      def recordable, do: unquote(opts[:recordable])

      @doc "Parser module that implements `Parse`."
      @spec parser :: module | nil
      def parser, do: unquote(opts[:parser])

      # Server functions

      @impl GenServer
      def init(nil), do: Server.init(__MODULE__)

      def shutdown(reason, _state), do: Server.shutdown(__MODULE__, reason)

      @impl GenServer
      def handle_call(request, from, state),
        do: Server.handle_call(__MODULE__, request, from, state)

      @impl GenServer
      def handle_cast(request, state), do: Server.handle_cast(__MODULE__, request, state)

      @impl State.Server
      def handle_new_state(new_state), do: Server.handle_new_state(__MODULE__, new_state)

      @impl State.Server
      def post_commit_hook, do: :ok

      @impl State.Server
      def post_load_hook(structs), do: structs

      @impl State.Server
      def pre_insert_hook(item), do: [item]

      @impl Events.Server
      def handle_event({:fetch, unquote(opts[:fetched_filename])}, body, _, state) do
        case handle_call({:new_state, body}, nil, state) do
          {:reply, _, new_state} ->
            maybe_hibernate({:noreply, new_state})

          {:reply, _, new_state, extra} ->
            maybe_hibernate({:noreply, new_state})
        end
      end

      unquote do
        if hibernate? do
          quote do
            def maybe_hibernate({:noreply, state}), do: {:noreply, state, :hibernate}
            def maybe_hibernate({:reply, reply, state}), do: {:reply, reply, state, :hibernate}
          end
        end
      end

      def maybe_hibernate(reply), do: reply

      # All functions that aren't metadata or have computed names, such as from def_by_indices,
      # should be marked overridable here
      defoverridable all: 0,
                     all: 1,
                     handle_call: 3,
                     handle_cast: 2,
                     handle_new_state: 1,
                     init: 1,
                     last_updated: 0,
                     match: 2,
                     match: 3,
                     new_state: 1,
                     new_state: 2,
                     post_commit_hook: 0,
                     post_load_hook: 1,
                     pre_insert_hook: 1,
                     select: 1,
                     select: 2,
                     select_limit: 2,
                     shutdown: 2,
                     size: 0,
                     start_link: 0,
                     start_link: 1,
                     update_metadata: 0
    end
  end

  def handle_call(module, {:new_state, enum}, _from, state) do
    module.handle_new_state(enum)
    module.maybe_hibernate({:reply, :ok, state})
  end

  def handle_call(module, :last_updated, _from, state) do
    module.maybe_hibernate({:reply, Map.get(state, :last_updated), state})
  end

  def handle_cast(module, :update_metadata, state) do
    state = %{state | last_updated: DateTime.utc_now()}
    State.Metadata.state_updated(module, state.last_updated)
    module.maybe_hibernate({:noreply, state})
  end

  def handle_new_state(module, func) when is_function(func, 0) do
    do_handle_new_state(module, func)
  end

  def handle_new_state(module, new_state) do
    parser = module.parser()

    if not is_nil(parser) and is_binary(new_state) do
      parse_new_state(module, parser, new_state)
    else
      do_handle_new_state(module, fn -> new_state end)
    end
  end

  def init(module) do
    :ok = recreate_table(module)
    fetched_filename = module.fetched_filename()

    if fetched_filename do
      subscribe({:fetch, fetched_filename})
    end

    Events.publish({:new_state, module}, 0)

    {:ok, %{last_updated: nil, data: nil}, :hibernate}
  end

  @spec match(module, map, atom, opts :: Keyword.t()) :: [struct]
  def match(module, matcher, index, opts) when is_map(matcher) and is_atom(index) do
    select(module, [matcher], index, opts)
  end

  def table_name(module) do
    module
    |> Atom.to_string()
    |> String.replace("Elixir.", "")
    |> String.replace(".", "_")
  end

  def column_name(column) when is_atom(column) do
    column
    |> Atom.to_string()
    |> String.replace("?", "_")
  end

  def recreate_table(module) do
    table = table_name(module)
    recordable = module.recordable()
    indices = module.indices()
    attributes = recordable.fields()

    columns = Enum.map_join(attributes, ", ", fn column -> ~s["#{column_name(column)}"] end)

    {:ok, _} =
      Sql.transaction(fn db ->
        _ = Sql.query(db, "DROP TABLE IF EXISTS #{table}", [])
        _ = Sql.query(db, "CREATE TABLE #{table} (#{columns})", [])

        for index <- indices do
          _ =
            Sql.query(
              db,
              'CREATE INDEX IF NOT EXISTS #{table}__#{index} ON #{table} (#{column_name(index)})',
              []
            )
        end
      end)

    :ok
  end

  def shutdown(module, _reason) do
    _ =
      Sql.transaction(fn db ->
        _ = Sql.query(db, "DROP TABLE IF EXISTS #{table_name(module)}", [])
      end)

    :ok
  end

  def create!(func, module) do
    enum =
      debug_time(
        func,
        fn milliseconds ->
          "create_enum #{module} #{inspect(self())} took #{milliseconds}ms"
        end
      )

    if enum do
      create_children(enum, module)
    else
      :ok
    end
  end

  defp create_children(enum, module) do
    table = table_name(module)
    recordable = module.recordable()

    insert_sql_params = Enum.map_join(recordable.fields(), ", ", fn _ -> "?" end)

    chunk_size = div(30_000, length(recordable.fields()))

    values =
      enum
      |> Stream.flat_map(&module.pre_insert_hook/1)
      |> Stream.map(fn item ->
        item
        |> recordable.to_list()
        |> Enum.map(&bind_value/1)
      end)

    {:ok, _} =
      Sql.transaction(
        fn db ->
          _ = Sql.query(db, ["DELETE FROM ", table], [])

          for group <- Enum.chunk_every(values, chunk_size) do
            insert_group_params =
              for _ <- group do
                ["(", insert_sql_params, ")"]
              end
              |> Enum.intersperse(", ")

            _ =
              Sql.query(
                db,
                ["INSERT INTO ", table, " VALUES ", insert_group_params],
                List.flatten(group)
              )
          end
        end,
        timeout: 280_000
      )

    :ok
  end

  defp bind_value(value) when is_integer(value) or is_binary(value) or is_nil(value) do
    value
  end

  defp bind_value(value) do
    {:blob, <<0>> <> :erlang.term_to_binary(value)}
  end

  defp unbind_value(<<first::binary-1, _::binary>> = value) when first != <<0>> do
    value
  end

  defp unbind_value("" = value) do
    value
  end

  defp unbind_value(value) when is_integer(value) or is_nil(value) do
    value
  end

  defp unbind_value(<<0>> <> value) do
    :erlang.binary_to_term(value)
  end

  def size(module) do
    {:ok, count} =
      Sql.transaction(fn db ->
        {:ok, result} = Sql.query(db, ["SELECT COUNT(*) FROM ", table_name(module)], [])
        [[count]] = result.rows
        count
      end)

    count
  end

  def all(module, opts) do
    {:ok, rows} =
      Sql.transaction(fn db ->
        {:ok, result} = Sql.query(db, ["SELECT * FROM ", table_name(module)], [])
        result.rows
      end)

    to_structs(rows, module, opts)
  end

  def all_keys(module) do
    [first_key | _] = module.recordable().fields()

    {:ok, values} =
      Sql.transaction(fn db ->
        {:ok, result} =
          Sql.query(
            db,
            ["SELECT DISTINCT ", column_name(first_key), " FROM ", table_name(module)],
            []
          )

        result.rows
        |> List.flatten()
        |> Enum.map(&unbind_value/1)
      end)

    values
  end

  def by_index(values, module, indicies, opts)

  def by_index([], _module, _indicies, _opts) do
    []
  end

  def by_index([nil], module, {index, _key_index}, opts) do
    Sql.run(fn db ->
      column = column_name(index)

      {:ok, result} =
        Sql.query(db, ["SELECT * FROM ", table_name(module), "WHERE ", column, " IS NULL"], [])

      to_structs(result.rows, module, opts)
    end)
  end

  def by_index([value], module, {index, _key_index}, opts) do
    Sql.run(fn db ->
      column = column_name(index)
      value = bind_value(value)

      {:ok, result} =
        Sql.query(db, ["SELECT * FROM ", table_name(module), " WHERE ", column, " = ?"], [value])

      to_structs(result.rows, module, opts)
    end)
  end

  def by_index(values, module, {index, _key_index}, opts) do
    # IO.inspect({module, :by_index, index, values})

    Sql.run(fn db ->
      column = column_name(index)

      wheres =
        for value <- values do
          if is_nil(value) do
            [column, " IS NULL"]
          else
            [column, " = ?"]
          end
        end
        |> Enum.intersperse(" OR ")

      where_values = Enum.reject(values, &is_nil/1)

      {order_by, order_by_values} =
        case values do
          [] ->
            {[], []}

          [_] ->
            {[], []}

          [_ | _] ->
            order_by = [
              " ORDER BY CASE ",
              column,
              values
              |> Enum.with_index()
              |> Enum.map(fn {_, i} ->
                [" WHEN ? THEN ", Integer.to_string(i)]
              end),
              " END"
            ]

            {order_by, values}
        end

      {:ok, result} =
        Sql.query(
          db,
          ["SELECT * FROM ", table_name(module), " WHERE ", wheres, order_by],
          Enum.map(where_values ++ order_by_values, &bind_value/1)
        )

      to_structs(result.rows, module, opts)
    end)
  end

  @spec select(module, [map], atom | nil, Keyword.t()) :: [struct]
  def select(module, matchers, index \\ nil, opts \\ [])

  def select(_module, [], _index, _opts) do
    []
  end

  def select(module, matchers, index, opts) when is_list(matchers) and is_atom(index) do
    # IO.inspect({module, :select, index, matchers})

    Sql.run(fn db ->
      {wheres, values} = where_query(matchers)

      {:ok, result} =
        Sql.query(
          db,
          ["SELECT * FROM ", table_name(module), " WHERE ", wheres],
          Enum.map(values, &bind_value/1)
        )

      to_structs(result.rows, module, opts)
    end)
  end

  def select_limit(module, matchers, num_objects, opts \\ [])

  def select_limit(_module, [], num_objects, _opts) when is_integer(num_objects) do
    []
  end

  def select_limit(module, matchers, num_objects, opts) when is_integer(num_objects) do
    Sql.run(fn db ->
      {wheres, values} = where_query(matchers)

      {:ok, result} =
        Sql.query(
          db,
          ["SELECT * FROM ", table_name(module), " WHERE ", wheres, "LIMIT ?"],
          Enum.map(values, &bind_value/1) ++ [num_objects]
        )

      to_structs(result.rows, module, opts)
    end)
  end

  defp where_query(matchers) do
    {wheres, where_values} =
      Enum.reduce(matchers, {[], []}, fn matcher, {wheres, where_values} ->
        if matcher == %{} do
          {["1" | wheres], where_values}
        else
          where =
            for {index, value} <- matcher do
              if is_nil(value) do
                [column_name(index), " IS NULL"]
              else
                [column_name(index), "= ?"]
              end
            end
            |> Enum.intersperse(" AND ")

          values =
            Enum.flat_map(matcher, fn {_index, value} ->
              if is_nil(value), do: [], else: [value]
            end)

          {[["(", where, ")"] | wheres], values ++ where_values}
        end
      end)

    {Enum.intersperse(wheres, " OR "), where_values}
  end

  defp to_structs(records, module, opts) do
    recordable = module.recordable()

    records
    |> Enum.map(fn values ->
      recordable.from_list(Enum.map(values, &unbind_value/1))
    end)
    |> module.post_load_hook()
    |> State.all(opts)
  end

  def log_parse_error(module, e) do
    _ = Logger.error("#{module} error parsing binary state: #{inspect(e)}")
    _ = Logger.error(Exception.format(:error, e))
    nil
  end

  defp def_by_index(index, keywords) do
    key_index = Keyword.fetch!(keywords, :key_index)
    name = :"by_#{index}"
    plural_name = :"#{name}s"

    quote do
      def unquote(name)(value, opts \\ []) do
        Server.by_index([value], __MODULE__, {unquote(index), unquote(key_index)}, opts)
      end

      def unquote(plural_name)(values, opts \\ []) when is_list(values) do
        Server.by_index(values, __MODULE__, {unquote(index), unquote(key_index)}, [])
      end

      defoverridable [
        {unquote(name), 1},
        {unquote(name), 2},
        {unquote(plural_name), 1},
        {unquote(plural_name), 2}
      ]
    end
  end

  def def_by_indices(indices, keywords) do
    key_index = Keyword.fetch!(keywords, :key_index)

    for index <- indices do
      def_by_index(index, key_index: key_index)
    end
  end

  defp do_handle_new_state(module, func) do
    :ok =
      debug_time(
        fn -> create!(func, module) end,
        fn milliseconds ->
          "init_table #{module} #{inspect(self())} took #{milliseconds}ms"
        end
      )

    :ok =
      debug_time(
        &module.post_commit_hook/0,
        fn milliseconds ->
          # coveralls-ignore-start
          "post_commit #{module} #{inspect(self())} took #{milliseconds}ms"
          # coveralls-ignore-stop
        end
      )

    new_size = module.size()

    _ =
      Logger.info(fn ->
        "Update #{module} #{inspect(self())}: #{new_size} items"
      end)

    module.update_metadata()
    Events.publish({:new_state, module}, new_size)

    :ok
  end

  defp parse_new_state(module, parser, binary) when is_binary(binary) do
    do_handle_new_state(module, fn ->
      try do
        parser.parse(binary)
      rescue
        e -> log_parse_error(module, e)
      end
    end)
  end
end
