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
  def match(module, matcher, index, opts) when map_size(matcher) == 1 and is_atom(index) do
    # if there's only one value for the matcher, then it's a simpler index read
    %{^index => value} = matcher
    by_index([value], module, {index, module.key_index()}, opts)
  end

  def match(module, matcher, index, opts) when is_map(matcher) and is_atom(index) do
    match = merge_with_filled(module, matcher)

    by_index_match(match, module, index, opts)
  end

  def merge_with_filled(module, matcher) do
    recordable = module.recordable()

    :_
    |> recordable.filled()
    |> Map.merge(matcher)
    |> recordable.to_record()
  end

  def recreate_table(module) do
    recordable = module.recordable()
    indices = module.indices()
    attributes = recordable.fields()
    key_index = module.key_index()
    index = Enum.reject(indices, &Kernel.==(&1, key_index))
    recreate_table(module, attributes: attributes, index: index, record_name: recordable)
  end

  def recreate_table(module, keywords) do
    case :mnesia.create_table(
           module,
           record_name: Keyword.fetch!(keywords, :record_name),
           attributes: Keyword.fetch!(keywords, :attributes),
           index: Keyword.fetch!(keywords, :index),
           storage_properties: [ets: [{:read_concurrency, true}]],
           type: :bag,
           local_content: true
         ) do
      {:atomic, :ok} ->
        :mnesia.wait_for_tables([module], 5_000)

      {:aborted, {:already_exists, _}} ->
        {:atomic, :ok} = :mnesia.delete_table(module)
        recreate_table(module, keywords)
    end
  end

  def shutdown(module, _reason) do
    {:atomic, :ok} = :mnesia.delete_table(module)
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
      has_hook? = function_exported?(module, :pre_insert_hook, 1)

      update =
        case enum do
          {:partial, enum} when has_hook? ->
            {:partial, Stream.flat_map(enum, &module.pre_insert_hook/1)}

          {:partial, _enum} = update ->
            update

          enum when has_hook? ->
            {:all, Stream.flat_map(enum, &module.pre_insert_hook/1)}

          enum ->
            {:all, enum}
        end

      with {:atomic, count} <-
             :mnesia.transaction(&create_children/2, [update, module], 10) do
        {:ok, count}
      end
    else
      {:ok, 0}
    end
  end

  defp create_children({:all, enum}, module) do
    recordable = module.recordable()
    :mnesia.write_lock_table(module)

    delete_all = fn ->
      all_keys = :mnesia.all_keys(module)

      :lists.foreach(&:mnesia.delete(module, &1, :write), all_keys)
    end

    write_new = fn ->
      Enum.reduce(enum, 0, fn item, count ->
        :mnesia.write(module, recordable.to_record(item), :write)
        count + 1
      end)
    end

    :ok =
      debug_time(
        delete_all,
        fn milliseconds ->
          "delete_all #{module} #{inspect(self())} took #{milliseconds}ms"
        end
      )

    count =
      debug_time(
        write_new,
        fn milliseconds ->
          "write_new #{module} #{inspect(self())} took #{milliseconds}ms"
        end
      )

    count
  end

  defp create_children({:partial, enum}, module) do
    recordable = module.recordable()
    key_index = module.key_index()

    update = fn ->
      enum
      |> Enum.group_by(&Map.get(&1, key_index))
      |> Enum.reduce(0, fn {key, items}, count ->
        :mnesia.delete(module, key, :write)
        :lists.foreach(&:mnesia.write(module, recordable.to_record(&1), :write), items)
        length(items) + count
      end)
    end

    count =
      debug_time(
        update,
        fn milliseconds ->
          "partial_update #{module} #{inspect(self())} took #{milliseconds}ms"
        end
      )

    count
  end

  def size(module) do
    :mnesia.table_info(module, :size)
  end

  def all(module, opts) do
    module
    |> :ets.tab2list()
    |> to_structs(module, opts)
  rescue
    ArgumentError ->
      # if the table is being rebuilt, we re-try to get the data
      all(module, opts)
  end

  def all_keys(module) do
    :mnesia.ets(fn ->
      :mnesia.all_keys(module)
    end)
  end

  def by_index(values, module, indices, opts) do
    indices
    |> build_read_fun(module)
    |> :lists.flatmap(values)
    |> to_structs(module, opts)
  catch
    :exit, {:aborted, {_, [^module | _]}} ->
      by_index(values, module, indices, opts)
  end

  defp build_read_fun({key_index, key_index}, module) do
    &:mnesia.dirty_read(module, &1)
  end

  defp build_read_fun({index, _key_index}, module) do
    &:mnesia.dirty_index_read(module, &1, index)
  end

  def by_index_match(match, module, index, opts) do
    module
    |> :mnesia.dirty_index_match_object(match, index)
    |> to_structs(module, opts)
  end

  def matchers_to_selectors(module, matchers) do
    for matcher <- matchers do
      {merge_with_filled(module, matcher), [], [:"$_"]}
    end
  end

  @spec select(module, [map], atom | nil) :: [struct]
  def select(module, matchers, index \\ nil)

  def select(module, matchers, nil) when is_list(matchers) do
    selectors = matchers_to_selectors(module, matchers)
    select_with_selectors(module, selectors)
  end

  def select(module, [matcher], index) when is_atom(index) do
    module.match(matcher, index)
  end

  def select(module, matchers, index) when is_list(matchers) and is_atom(index) do
    :lists.flatmap(&module.match(&1, index), matchers)
  end

  def select_with_selectors(module, selectors) when is_atom(module) and is_list(selectors) do
    fn ->
      :mnesia.select(module, selectors)
    end
    |> :mnesia.async_dirty()
    |> to_structs(module, [])
  end

  def select_limit(module, matchers, num_objects) do
    selectors = matchers_to_selectors(module, matchers)
    select_limit_with_selectors(module, selectors, num_objects)
  end

  def select_limit_with_selectors(module, selectors, num_objects) do
    case :mnesia.async_dirty(fn ->
           :mnesia.select(module, selectors, num_objects, :read)
         end) do
      :"$end_of_table" ->
        []

      {records, _cont} ->
        to_structs(records, module, [])
    end
  end

  defp to_structs(records, module, opts) do
    recordable = module.recordable()

    records
    |> Enum.map(&recordable.from_record/1)
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
    {:ok, update_count} =
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

    _ =
      Logger.info(fn ->
        "Update #{module} #{inspect(self())}: #{update_count} items"
      end)

    module.update_metadata()
    Events.publish({:new_state, module}, update_count)

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
