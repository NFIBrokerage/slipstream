defmodule Slipstream.SocketTest do
  @moduledoc """
  Helper functions and macros for testing Slipstream clients

  This module is something of a correlary to `Phoenix.ChannelTest`. The
  functions and macros in `Phoenix.ChannelTest` emulate client operations:
  functions like `Phoenix.ChannelTest.join/2`, `Phoenix.ChannelTest.push/3`,
  etc.. Functions and macros in this module emulate behavior of the server:
  a `Phoenix.Channel`.

  ## Timing assumptions

  Clients are typically written to assume that the server

  - is up at time of client start-up
  - is always up

  While this is typically (at least mostly) accurate, it is not necessarily
  true in general and will not be true when testing Slipstream clients. In
  particular, Slipstream clients may fail in test-mode under the following
  conditions:

  - the client is started immediately in the application supervision tree
  - it awaits a connection synchronously (with `Slipstream.await_connect/2`)
  - the testing suite takes longer to complete than the timeout given to
    `Slipstream.await_connect/2`

  While a client that uses `Slipstream.await_connect/2` can band-aid over
  these problems with a high enough timeout, clients should be satisfied with
  receiving successful connection events asynchronously. Clients written in
  the asynchronous callback style will not be affected.

  Some implementation-level details are glossed over by this testing framework,
  including that of heartbeat timeouts. If a client sits idle after joining
  for more than 60 seconds, they will not be terminated due to heartbeat
  timeout.

  ## Setting up a test

  Another assumption clients typically make of servers is that clients assume
  there is just _one_ server. A client is not written expecting to hear that it
  has been connected multiple times for one request to `Slipstream.connect/2`.
  As such, tests using this module as a case template should be run
  synchronously.

      defmodule MyApp.MyClientTest do
        use Slipstream.SocketTest

        ..

  By default, this will start a server session for each test that simulates
  the current test process as the websocket server connected to the client.

      test "the client sends a push to the server on join", c do
        accept_connect(MyClient)
      end

  This server does not run a websocket server. Instead the server is
  a conceptual server: you may imagine that in each test, you are have control
  of the remote server and can control the behavior of the server imperatively.

  The `assert_*` and `refute_*` family of macros from this module allow you to
  make assertions about- and match on values from- requests from the client to
  the server. The remaining functions allow you to emulate actions on behalf
  of a hypothetical server.

  ## Starting the client

  When working with `accept_conect/1` and `connect_and_assert_join/5`, you may
  either pass the name of the GenServer to test, or a pid. If starting the client
  yourself, make sure that you pass the `test_mode?: true` option, otherwise the
  Slipstream client will attempt to connect to the configured uri.

      defmodule MyApp.MyClientTest do
        use Slipstream.SocketTest

        setup do
          client = start_supervised!(MyApp.Myclient, uri: "wss://test.com", test_mode?: true)
          %{client: client}
        end

  ## Timeouts

  The `assert_*` and `refute_*` macros from this module default to ExUnit
  timeouts. See the ExUnit documentation for more details.

  ## Formatting

  Slipstream exports the `assert_*` and `receive_*` macros as valid
  `locals_without_parens` in its formatter config. To be able to use these
  macros without the formatter injecting parentheses, import `:slipstream` in
  your service's formatter config for `:import_deps`:

      [
        inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
        import_deps: [:slipstream],
        .. # more configuration
      ]
  """
  @moduledoc since: "0.2.0"

  # implementation note:
  # Getting events to the client process is not difficult.
  # The author simply must provide the pid or GenServer name. Seizing the
  # commands being emitted by the client and sent to the connection process is
  # the name of the game. We do this with two edits to the usual behavior of a
  # client:
  #
  #   1. do not spawn a connection process with `Slipstream.connect/2`
  #   2. send a `Slipstream.Events.ChannelConnected` with a pid of the current
  #      test process

  use ExUnit.CaseTemplate

  import Slipstream.Signatures

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  @typedoc """
  Any Slipstream client

  Since Slipstream clients are either GenServer or plain processes, either
  a pid or a GenServer name will work as the `client` argument for any function
  specifying `client` in this module.
  """
  @typedoc since: "0.2.0"
  @type client :: pid() | GenServer.name()

  # --- functions seeking to modify the state of a client

  @doc """
  Emulates a server telling the client it has connected

  This sets the current process as the current server connected to the client.
  It also adds an `ExUnit.callbacks.on_exit/2` function that disconnects the
  client on exit with reason `:closed_by_test`. To handle this disconnect,
  clients should match on this pattern in `c:Slipstream.handle_disconnect/2`
  and either shutdown (in the case that the test controls the spawning of the
  client, or reconnect, as with `Slipstream.reconnect/1`. The default
  implementation of `c:Slipstream.handle_disconnect/2` reconnects in this case.

  See [Timing Assumptions](#module-timing-assumptions).

  ## Examples

      test "the server connects", c do
        :ok = accept_connect(MyApp.MyClient)
      end
  """
  @doc since: "0.2.0"
  @spec accept_connect(client()) :: :ok
  def accept_connect(client) do
    client = __check_client__(client)

    send(client, event(%Slipstream.Events.ChannelConnected{pid: self()}))

    # coveralls-ignore-start
    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(client) do
        send(
          client,
          event(%Slipstream.Events.ChannelClosed{reason: :closed_by_test})
        )
      end

      :ok
    end)

    # coveralls-ignore-stop

    :ok
  end

  @doc """
  Emulates a server pushing a message to the client

  This emulates cases of `Phoenix.Channel.push/3` by a Phoenix server.

  Note that this function will not encode or decode the value of `params`, so
  conversion from maps of atom-keys to string-keys will not occur as it would
  when passing messages over-the-wire.

  ## Examples

      test "the server increments our counter with ping messages", c do
        assert Counter.count() == 0

        connect_and_assert_join MyClient, "counter-topic", %{}, :ok

        push(MyClient, "counter-topic", "ping", %{delta: 1})

        assert Counter.count() == 1
      end
  """
  @doc since: "0.2.0"
  @spec push(
          client :: client(),
          topic :: String.t(),
          event :: String.t(),
          params :: Slipstream.json_serializable()
        ) :: :ok
  def push(client, topic, event, params) do
    client
    |> __check_client__()
    |> send(
      event(%Slipstream.Events.MessageReceived{
        topic: topic,
        event: event,
        payload: params
      })
    )

    :ok
  end

  @doc """
  Emulates a server replying to a push from the client

  `ref` is a reference which can be matched upon in `assert_push/6`. `reply`
  follows the `t:Slipstream.reply/0` type: it may be an `:ok` or `:error`
  atom or an `{:ok, any()}` or `{:error, any()}` tuple. This value will not
  be encoded or decoded by Slipstream, instead just directly passed to the
  client.

  ## Examples

      topic = "rooms:lobby"
      connect_and_assert_join MySocketClient, ^topic, %{}, :ok
      assert_push ^topic, "ping", %{}, ref
      reply(MySocketClient, ref, {:ok, %{"ping" => "pong"}})
  """
  @doc since: "0.2.0"
  @spec reply(
          client :: client(),
          ref :: Slipstream.push_reference(),
          reply :: Slipstream.reply()
        ) :: :ok
  def reply(client, ref, reply) do
    client
    |> __check_client__()
    |> send(event(%Slipstream.Events.ReplyReceived{ref: ref, reply: reply}))

    :ok
  end

  @doc """
  Emulates a server closing a connection to the client

  ## Examples

      accept_connect(MyClient)
      disconnect(MyClient, :heartbeat_timeout)
  """
  @doc since: "0.2.0"
  @spec disconnect(client :: client(), reason :: term()) :: :ok
  def disconnect(client, reason) do
    client
    |> __check_client__()
    |> send(event(%Slipstream.Events.ChannelClosed{reason: reason}))

    :ok
  end

  # --- macros asserting that a client has performed an action

  @doc """
  A convenience macro wrapping connection and a join response

  This macro is written for clients that join immediately after a connection has
  been established, which is a common case.

  Clients written like so:

      @impl Slipstream
      def handle_connect(socket) do
        {:ok, join(socket, "rooms:lobby", %{user_id: socket.assigns.user_id})}
      end

  May be tested with `connect_and_assert_join/5` as opposed to a separate `connect/2`
  and then an `assert_join/5`.

  ## Examples

      socket = connect_and_assert_join MySocketClient, "rooms:lobby", %{}, :ok
      push(socket, "rooms:lobby", "initial-hello", %{"hello" => "world"})
  """
  @doc since: "0.2.0"
  @spec connect_and_assert_join(
          client :: pid() | GenServer.name(),
          topic_expr :: Macro.t(),
          params_expr :: Macro.t(),
          reply :: Slipstream.reply(),
          timeout()
        ) :: term()
  defmacro connect_and_assert_join(
             client,
             topic_expr,
             params_expr,
             reply,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :assert_receive_timeout
             )
           ) do
    quote do
      unquote(__MODULE__).accept_connect(unquote(client))

      unquote(__MODULE__).assert_join(
        unquote(topic_expr),
        unquote(params_expr),
        unquote(reply),
        unquote(timeout)
      )
    end
  end

  @doc """
  Asserts that a client will request to join a topic

  `topic_expr` and `params_expr` are interpreted as match expressions, so they
  may be literal values, pinned (`^`) bindings, or partial values such as
  `"msg:" <> _` or `%{}` (which matches any map).

  `reply` is meant to simulate the return value of the
  `c:Phoenix.Channel.join/3` callback.

  ## Examples

      accept_connect(MyClient)
      assert_join "rooms:lobby", %{}, :ok
  """
  @doc since: "0.2.0"
  @spec assert_join(
          topic_expr :: Macro.t(),
          params_expr :: Macro.t(),
          reply ::
            :ok
            | :error
            | {:ok, Slipstream.json_serializable()}
            | {:error, Slipstream.json_serializable()},
          timeout()
        ) :: term()
  defmacro assert_join(
             topic_expr,
             params_expr,
             reply,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :assert_receive_timeout
             )
           ) do
    quote do
      return =
        assert_receive command(%Slipstream.Commands.JoinTopic{
                         socket: socket,
                         topic: unquote(topic_expr) = topic,
                         payload: unquote(params_expr)
                       }),
                       unquote(timeout)

      join_event =
        unquote(__MODULE__).__map_join_reply__(unquote(reply))
        |> Map.put(:topic, topic)

      send(socket.socket_pid, event(join_event))

      return
    end
  end

  @doc """
  Refutes that a client will request to join a topic

  The opposite of `assert_join/5`.

  ## Examples

      accept_connect(MySocketClient)
      refute_join "rooms:" <> _, %{user_id: 5}
  """
  @doc since: "0.2.0"
  @spec refute_join(
          topic_expr :: Macro.t(),
          params_expr :: Macro.t(),
          timeout()
        ) :: term()
  defmacro refute_join(
             topic_expr,
             params_expr,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :refute_receive_timeout
             )
           ) do
    quote do
      refute_receive command(%Slipstream.Commands.JoinTopic{
                       topic: unquote(topic_expr),
                       payload: unquote(params_expr)
                     }),
                     unquote(timeout)
    end
  end

  @doc """
  Asserts that a client will request to leave a topic

  `topic_expr` is a pattern, so literal values like `"room:lobby"` are valid
  as well as match patterns such as `"room:" <> _`. Existing bindings must be
  pinned with the `^` pin operator.

  ## Examples

      topic = "rooms:lobby"
      accept_connect(MyClient)
      assert_join ^topic, %{}, :ok
      push(MyClient, topic, "leave", %{})
      assert_leave ^topic
  """
  @doc since: "0.2.0"
  @spec assert_leave(topic_expr :: Macro.t(), timeout()) ::
          term()
  defmacro assert_leave(
             topic_expr,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :assert_receive_timeout
             )
           ) do
    quote do
      return =
        assert_receive command(%Slipstream.Commands.LeaveTopic{
                         socket: socket,
                         topic: unquote(topic_expr) = topic
                       }),
                       unquote(timeout)

      send(
        socket.socket_pid,
        event(%Slipstream.Events.TopicLeft{topic: topic})
      )

      return
    end
  end

  @doc """
  Refutes that a client will request to leave a topic

  The opposite of `assert_leave/3`.

  ## Examples

      accept_connect(MyClient)
      assert_join "rooms:lobby", %{}, :ok
      push(MyClient, topic, "no-don't-go", %{})
      refute_leave ^topic, 10_000
  """
  @doc since: "0.2.0"
  @spec refute_leave(topic_expr :: Macro.t(), timeout()) :: term()
  defmacro refute_leave(
             topic_expr,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :refute_receive_timeout
             )
           ) do
    quote do
      refute_receive command(%Slipstream.Commands.LeaveTopic{
                       topic: unquote(topic_expr)
                     }),
                     unquote(timeout)
    end
  end

  @doc """
  Asserts that the client will request to push a message to the server

  Note that `topic_expr`, `event_expr`, `params_expr`, and `ref_expr` are all
  pattern expressions. Prior bindings may be used with the `^` pin operator,
  values may be underscored to ignore, and partial values may be matched (e.g.
  `%{}` will match any map).

  `ref_expr` can be provided to bind a reference for later use in `reply/3`.

  ## Examples

      assert_push "rooms:lobby", "msg:new", params, ref
      reply(MyClient, ref, {:ok, %{status: "ok", received: params}})
  """
  @doc since: "0.2.0"
  @spec assert_push(
          topic_expr :: Macro.t(),
          event_expr :: Macro.t(),
          params_expr :: Macro.t(),
          ref_expr :: Macro.t(),
          timeout()
        ) :: term()
  defmacro assert_push(
             topic_expr,
             event_expr,
             params_expr,
             ref_expr \\ quote(do: _),
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :assert_receive_timeout
             )
           ) do
    quote do
      # incrementing integer? who needs it
      unquote(ref_expr) = ref = make_ref() |> inspect()

      return =
        assert_receive gen_server_call(
                         command(%Slipstream.Commands.PushMessage{
                           topic: unquote(topic_expr) = topic,
                           event: unquote(event_expr) = event,
                           payload: unquote(params_expr) = payload
                         }),
                         from
                       ),
                       unquote(timeout)

      GenServer.reply(from, ref)

      return
    end
  end

  @doc """
  Refutes that a client will push a message to the server

  The opposite of `assert_push/4`

  ## Examples

      refute_push "rooms:lobby", "msg:" <> _, %{user_id: 5}
  """
  @doc since: "0.2.0"
  @spec refute_push(
          topic_expr :: Macro.t(),
          event_expr :: Macro.t(),
          params_expr :: Macro.t(),
          timeout()
        ) :: term()
  defmacro refute_push(
             topic_expr,
             event_expr,
             params_expr,
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :refute_receive_timeout
             )
           ) do
    quote do
      refute_receive gen_server_call(
                       command(%Slipstream.Commands.PushMessage{
                         topic: unquote(topic_expr),
                         event: unquote(event_expr),
                         payload: unquote(params_expr)
                       }),
                       _from
                     ),
                     unquote(timeout)
    end
  end

  @doc """
  Asserts that a client will attempt to disconnect from the server

  ## Examples

      accept_connect(MyClient)
      # client will disconnect after 15s of inactivity
      assert_disconnect 15_000
  """
  @doc since: "0.2.0"
  @spec assert_disconnect(timeout()) :: term()
  defmacro assert_disconnect(
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :assert_receive_timeout
             )
           ) do
    quote do
      return =
        assert_receive command(%Slipstream.Commands.CloseConnection{
                         socket: socket
                       }),
                       unquote(timeout)

      send(
        socket.socket_pid,
        event(%Slipstream.Events.ChannelClosed{reason: :closed_by_remote})
      )

      return
    end
  end

  @doc """
  Refutes that a client will attempt to disconnect from the server

  The opposite of `assert_disconnect/1`.

  ## Examples

      accept_connect(MyClient)
      refute_disconnect 10_000
  """
  @doc since: "0.2.0"
  @spec refute_disconnect(timeout()) :: term()
  defmacro refute_disconnect(
             timeout \\ Application.fetch_env!(
               :ex_unit,
               :refute_receive_timeout
             )
           ) do
    quote do
      refute_receive command(%Slipstream.Commands.CloseConnection{}),
                     unquote(timeout)
    end
  end

  @doc false
  @doc since: "0.2.0"
  @spec __check_client__(pid() | GenServer.name()) :: pid() | no_return()
  # checks that the client is a process we may send to
  def __check_client__(client)

  def __check_client__(client) do
    with pid when is_pid(pid) <- GenServer.whereis(client),
         true <- Process.alive?(pid) do
      pid
    else
      false ->
        raise ArgumentError,
          message: "cannot send to client #{inspect(client)} that is not alive"

      _other_value ->
        raise ArgumentError,
          message: "cannot find pid for client #{inspect(client)}"
    end
  end

  @doc false
  @doc since: "0.2.0"
  @spec __map_join_reply__(
          reply ::
            :ok
            | :error
            | {:ok, Slipstream.json_serializable()}
            | {:error, Slipstream.json_serializable()}
        ) ::
          Slipstream.Events.TopicJoinSucceeded.t()
          | Slipstream.Events.TopicJoinFailed.t()
  def __map_join_reply__(reply)

  def __map_join_reply__(:ok), do: __map_join_reply__({:ok, %{}})

  def __map_join_reply__(:error),
    do: __map_join_reply__({:error, %{"error" => "join crashed"}})

  def __map_join_reply__({:ok, params}) do
    %Slipstream.Events.TopicJoinSucceeded{response: params}
  end

  def __map_join_reply__({:error, params}) do
    %Slipstream.Events.TopicJoinFailed{response: params}
  end
end
