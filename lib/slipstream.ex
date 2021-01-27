defmodule Slipstream do
  @moduledoc """
  A websocket client for Phoenix channels

  Slipstream is a websocket client for connection to `Phoenix.Channel`s.
  Slipstream is a bit different from existing websocket implementations in that:

  - it's backed by `:gun` instead of `:websocket_client`
  - it emits telemetry (via `:telemetry`)

  ## Synchronicity

  Slipstream is designed to work asynchronously by default. Requests such
  as `connect/2`, `join/3`, and `push/4` are asynchronous requests. When
  the remote server replies, the associated callback will be invoked
  (`c:handle_connect/1`, `c:handle_join/3`, and `c:handle_reply/3` in cases
  of success, respectively). For all of these operations, though, you may
  await the outcome of the asynchronous request with `await_*` functions. E.g.

      iex> ref = push(socket, "room:lobby", "msg:new", %{user: 1, msg: "foo"})
      iex> {:ok, %{"created" => true}} = await_reply(ref)

  Note that all `await_*` functions must be called from the slipstream process
  that emitted the request, or else they will timeout.

  While Slipstream provides a rich toolset for synchronicity, the asynchronous,
  callback-based workflow is recommended.

  ## GenServer operations

  Note that Slipstream is in many ways a simple wrapper around a GenServer.
  As such, all GenServer functionality is possible with Slipstream servers,
  such as `Kernel.send/2` or `GenServer.call/3`

      iex> MySlipstreamModule |> GenServer.whereis |> send(:hello)
      :hello
      iex> GenServer.call(MySlipstreamModule, {:send_message, message})
      {:ok, %{sent?: true}}

  Where the second example invokes the `c:handle_call/3` callback.
  """

  alias Slipstream.{Commands, Events, Socket, CommandRouter}

  # 5s default await timeout, same as GenServer calls
  @default_timeout 5_000

  @typedoc """
  Any data structure capable of being serialized as JSON

  Any argument typed as `t:Slipstream.json_serializable/0` must be able to
  be encoded with the JSON parser passed in configuration. See
  `Slipstream.Configuration`.
  """
  @typedoc since: "1.0.0"
  @type json_serializable :: term()

  @typedoc """
  A reference to a message pushed by the client

  These references are returned by calls to `push/4` and may be matched on
  in `c:handle_reply/3`. They are also used to match messages
  for `await_reply/2`.

  ## Examples

      @impl Slipstream
      def handle_call({:new_message, params}, _from, socket) do
        ref = push(socket, "rooms:lobby", "msg:new", params)

        {:reply, await_reply(ref), socket}
      end

      @impl Slipstream
      def handle_info(:do_work, socket) do
        ref = push(socket, "worker_queue:foo", "do_work", %{})

        {:noreply, assign(socket, :work_ref, ref)}
      end

      @impl Slipstream
      def handle_reply(ref, result, %{assigns: %{work_ref: ref}} = socket) do
        IO.inspect(result, label: "work complete!")

        {:ok, socket}
      end
  """
  @typedoc since: "1.0.0"
  @type push_reference() ::
          {topic :: String.t(), message_reference :: String.t()}

  @typedoc """
  A reply from a remote server to a push from the client

  Replies may be any of

  - `:ok`
  - `:error`
  - `{:ok, any()}`
  - `{:error, any()}`

  depending on how the remote server's reply is written.

  Note that the empty map is removed in ok and error tuples, so a reply written
  like so on the server-side:

      def handle_in(_event, _params, socket) do
        {:reply, {:ok, %{}}, socket}
      end

  will translate to a reply of `:ok` (and the same for `{:error, %{}}`).

  ## Examples

      # on the Phoenix.Channel (server) side:
      def handle_in(_event, _params, socket) do
        {:reply, {:ok, %{created?: true}}, socket}
      end

      # on the Slipstream (client) side:
      def handle_reply(_ref, {:ok, %{"created?" => true}} = _reply, socket) do
        ..
  """
  @typedoc since: "1.0.0"
  @type reply() ::
          :ok
          | :error
          | {:ok, json_serializable()}
          | {:error, json_serializable()}

  # the family of GenServer-wrapping callbacks

  @doc """
  Invoked when the slipstream process in started

  Behaves the same as `c:GenServer.init/1`, but the return state must be a
  new `t:Slipstream.Socket.t/0`. Values from `c:init/1` that you'd
  like to keep in state can be stored with `Slipstream.Socket.assign/3`.

  This callback is a good place to request connection with `connect/2`. Note
  that `connect/2` is an asynchronous request for connection. Awaiting
  connection with `await_connect/2` is unwise in many scenarios, however,
  because failure to connect may result in an exit from the process, crashing
  the supervision tree that started the process. If you wish to connect
  synchronously upon init, a better approach could be:

      @impl Slipstream
      def init(_args) do
        config = Application.fetch_env!(:my_app, __MODULE__)
        socket = new_socket() |> assign(:connect_config, config)

        {:ok, socket, {:continue, :connect}}
      end

      @impl Slipstream
      def handle_continue(:connect, socket) do
        {:ok, socket} = connect(socket, socket.assigns.connect_config)

        {:ok, socket} = await_connect(socket)

        {:noreply, socket}
      end

  ## Examples

      @impl Slipstream
      def init(config) do
        {:ok, connect(config)}
      end
  """
  @doc since: "1.0.0"
  @callback init(init_arg :: any()) ::
              {:ok, state}
              | {:ok, state, timeout() | :hibernate | {:continue, term()}}
              | :ignore
              | {:stop, reason :: any()}
            when state: Socket.t()

  @doc """
  Invoked as a continuation of another GenServer callback

  GenServer callbacks may end with signatures that declare that the next
  function invoked should be a continuation. E.g.

      def init(state) do
        {:ok, state, {:continue, :my_continue}}
      end

      # this will be invoked immediately after `init/1`
      def handle_continue(:my_continue, state) do
        # do something with state

        {:norelpy, state}
      end

  This provides a way to schedule work to occur immediately after
  successful initialization or to break work across multiple callbacks, which
  can be useful for servers which are state-machine-like.

  See `c:GenServer.handle_continue/2` for more information.
  """
  @doc since: "1.0.0"
  @callback handle_continue(continue :: term(), state :: Socket.t()) ::
              {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: term(), new_state}
            when new_state: Socket.t()

  @doc """
  Invoked when a slipstream process receives a message

  Behaves the same as `c:GenServer.handle_info/2`
  """
  @doc since: "1.0.0"
  @callback handle_info(msg :: term(), socket :: Socket.t()) ::
              {:noreply, new_socket}
              | {:noreply, new_socket,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: term(), new_socket}
            when new_socket: Socket.t()

  @doc """
  Invoked when a slipstream process receives a GenServer cast

  Behaves the same as `c:GenServer.handle_cast/2`
  """
  @doc since: "1.0.0"
  @callback handle_cast(msg :: term(), socket :: Socket.t()) ::
              {:noreply, new_socket}
              | {:noreply, new_socket,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: term(), new_socket}
            when new_socket: Socket.t()

  @doc """
  Invoked when a slipstream process receives a GenServer call

  Behaves the same as `c:GenServer.handle_call/3`
  """
  @doc since: "1.0.0"
  @callback handle_call(
              request :: term(),
              from :: GenServer.from(),
              socket :: Socket.t()
            ) ::
              {:reply, reply, new_socket}
              | {:reply, reply, new_socket,
                 timeout() | :hibernate | {:continue, term()}}
              | {:noreply, new_socket}
              | {:noreply, new_socket,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason, new_socket}
              | {:stop, reason, reply, new_socket}
            when new_socket: Socket.t(), reply: term(), reason: term()

  @doc """
  Invoked when a slipstream process is terminated

  Note that this callback is not always invoked as the process shuts down.
  See `c:GenServer.terminate/2` for more information.
  """
  @callback terminate(reason :: term(), state :: term()) :: term()

  # callbacks unique to Slipstream ('novel' callbacks)

  @doc """
  Invoked when a connection has been established to a websocket server

  This callback provides a good place to join a `Phoenix.Channel`.

  ## Examples

      @impl Slipstream
      def handle_connect(state) do
        {:noreply, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_connect(state :: term()) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a connection has been terminated

  The default implementation of this callback requests reconnection

  ## Examples

      @impl Slipstream
      def handle_disconnect(_reason, state) do
        reconnect()

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_disconnect(reason :: term(), state :: term()) ::
              {:ok, new_state}
              | {:stop, stop_reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when the websocket server replies to the request to join

  The `:status` field declares whether the join was successful or not with
  values of `:success` or `:failure`

  ## Examples

      @impl Slipstream
      def handle_join(:success, %{}, state) do
        push("echo", %{"ping" => 1})

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_join(
              status :: :success | :failure,
              response :: json_serializable(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a message is received on the websocket connection

  This callback will not be invoked for a message which is a reply. Those
  messages will be handled in `c:handle_reply/3`.

  Note that while replying is supported on the server-side of the Phoenix
  Channel protocol, it is not supported by a client. Messages sent from
  the server cannot be directly replied to.

  ## Examples

      @impl Slipstream
      def handle_message("room:lobby", "new:msg", params, state) do
        MyApp.Msg.create(params)

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_message(
              topic :: String.t(),
              event :: String.t(),
              message :: any(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a message is received on the websocket connection which
  references a push from this client process.

  `ref` is the string reference returned from the `push/2` which resulted in
  this reply.

  ## Examples

      @impl Slipstream
      def handle_join(:success, _params, state) do
        my_req = push("msg:new", %{"foo" => "bar"})

        {:ok, Map.put(state, :request, my_req)}
      end

      @impl Slipstream
      def handle_reply(ref, reply, %{request: ref} = state) do
        IO.inspect(reply, label: "reply to my request")

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_reply(
              ref :: push_reference(),
              message :: reply(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a channel has been closed by the remote server

  The default implementation of this callback attempts to re-join the
  last-joined topic.

  ## Examples

      @impl Slipstream
      def handle_topic_close(topic, _message, state) do
        rejoin(socket, topic)

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_topic_close(
              topic :: String.t(),
              reason :: term(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, stop_reason :: term(), new_state}
            when new_state: term()

  @optional_callbacks init: 1,
                      handle_info: 2,
                      handle_cast: 2,
                      handle_call: 3,
                      handle_continue: 2,
                      terminate: 2,
                      handle_connect: 1,
                      handle_disconnect: 2,
                      handle_join: 3,
                      handle_message: 4,
                      handle_reply: 3,
                      handle_topic_close: 3

  # --- core functionality

  @doc """
  Starts a slipstream client process

  ## Examples

      defmodule MySlipstreamClient do
        use Slipstream

        def start_link(args) do
          Slipstream.start_link(__MODULE__, args, name: __MODULE__)
        end

        ..
      end
  """
  @spec start_link(module(), any()) :: GenServer.on_start()
  @spec start_link(module(), any(), GenServer.options()) :: GenServer.on_start()
  defdelegate start_link(module, init_arg), to: GenServer
  defdelegate start_link(module, init_arg, options), to: GenServer

  @doc """
  Creates a new socket without connecting to a remote websocket
  """
  @doc since: "1.0.0"
  @spec new_socket() :: Socket.t()
  defdelegate new_socket(), to: Socket, as: :new

  @doc """
  Requests connection to the remote endpoint

  `opts` are passed to `Slipstream.Configuration.validate/1` before sending.

  Note that this request for connection is asynchronous. A return value of
  `{:ok, socket}` does not mean that a connection has successfully been
  established.

  ## Examples

      {:ok, socket} = connect(uri: "ws://localhost:4000/socket/websocket")
  """
  @doc since: "1.0.0"
  @spec connect(opts :: Keyword.t()) ::
          {:ok, Socket.t()} | {:error, %NimbleOptions.ValidationError{}}
  @spec connect(socket :: Socket.t(), opts :: Keyword.t()) ::
          {:ok, Socket.t()} | {:error, %NimbleOptions.ValidationError{}}
  def connect(socket \\ new_socket(), opts) do
    case Slipstream.Configuration.validate(opts) do
      {:ok, config} ->
        %Commands.OpenConnection{config: config, socket: socket}
        |> CommandRouter.route_command()

        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as `connect/2` but raises on configuration validation error

  Note that `connect!/2` will not necessarily raise an error on failure to
  connect. The `!` only pertains to the potential for raising when the
  configuration is invalid.
  """
  @doc since: "1.0.0"
  @spec connect!(opts :: Keyword.t()) :: Socket.t()
  @spec connect!(socket :: Socket.t(), opts :: Keyword.t()) :: Socket.t()
  def connect!(socket \\ new_socket(), opts) do
    config = Slipstream.Configuration.validate!(opts)

    %Commands.OpenConnection{config: config, socket: socket}
    |> CommandRouter.route_command()

    socket
  end

  @doc """
  Request reconnection given the last-used connection configuration

  Note that when `reconnect/1` is used to re-connect instead of `connect/2`
  (or `connect!/2`), the slipstream process will attempt to reconnect with
  a retry mechanism with backoff. The process will wait an interval between
  reconnection attempts following the list of milliseconds provided in the
  `:reconnect_after_msec` key of configuration passed to `connect/2` (or
  `connect!/2`).

  The `c:handle_disconnect/2` callback will be invoked for each
  failure to re-connect, however, so an implementation of that callback which
  will simply retry with backoff can be achieved like so:

      @impl Slipstream
      def handle_disconnect(_reason, socket) do
        {:ok, socket} = reconnect(socket)
      end

  `reconnect/1` may return `:error` in the case that the socket passed does not
  contain any connection information (which is added to the socket with
  `connect/2` or `connect!/2`).

  A reconnect may be awaited with `await_connect/2`.
  """
  @doc since: "1.0.0"
  @spec reconnect(socket :: Socket.t()) :: {:ok, Socket.t()} | :error
  def reconnect(socket) do
    case socket.channel_config do
      nil ->
        :error

      config ->
        %Commands.OpenConnection{config: config, socket: socket}
        |> CommandRouter.route_command()
    end

    {:ok, socket}
  end

  @doc """
  Requests that a topic be joined in the current connection

  Multiple topics may be joined by one Slipstream client, but each topic
  may only be joined once. Despite this, `join/3` may be called on the same
  topic multiple times, but the result will be idempotent. The client will
  not request to join unless it has not yet joined that topic. In cases where
  you wish to begin a new session with a topic, you must first `leave/2` and
  then `join/3` again.

  The request to join will not error-out if the client is not connected to a
  remote server. In that case, the `join/3` function will act as a no-op.

  A join can be awaited in a blocking fashion with `await_join/3`.

  ## Examples

      @impl Slipstream
      def handle_connect(state) do
        {:ok, join(socket, "rooms:lobby", %{user: 1})
      end
  """
  @doc since: "1.0.0"
  @spec join(socket :: Socket.t(), topic :: String.t()) :: Socket.t()
  @spec join(
          socket :: Socket.t(),
          topic :: String.t(),
          params :: json_serializable()
        ) :: Socket.t()
  def join(%Socket{} = socket, topic, params \\ %{}) when is_binary(topic) do
    if Socket.connected?(socket) and
         Socket.join_status(socket, topic) in [nil, :closed] do
      %Commands.JoinTopic{socket: socket, topic: topic, payload: params}
      |> CommandRouter.route_command()

      Socket.put_join_config(socket, topic, params)
    else
      socket
    end
  end

  @doc """
  Requests that the specified topic be joined again

  If `params` is not provided, the previously used value will be sent.

  In the case that the specified topic has not been joined before, `rejoin/3`
  will return `{:error, :never_joined}`.

  Note that a rejoin may be awaited with `await_join/3`.

  ## Dealing with crashes

  When attempting to re-join a disconnected topic with `rejoin/3`, the
  Slipstream process will attempt to use backoff governed by the
  `:rejoin_after_msec` list in configuration passed to `connect/2` (or
  `connect!/2`).

  The `c:handle_topic_close/3` callback will be invoked with
  the for each crash, however, so a minimal implementation of that callback
  which achieves the backoff retry is like so:

  ## Examples

      @impl Slipstream
      def handle_topic_close(topic, _reason, socket) do
        {:ok, _socket} = rejoin(socket, topic)
      end
  """
  @doc since: "1.0.0"
  @spec rejoin(socket :: Socket.t(), topic :: String.t()) ::
          {:ok, Socket.t()} | {:error, :never_joined}
  @spec rejoin(
          socket :: Socket.t(),
          topic :: String.t(),
          params :: json_serializable()
        ) :: {:ok, Socket.t()} | {:error, :never_joined}
  def rejoin(%Socket{} = socket, topic, params \\ nil) when is_binary(topic) do
    case Map.fetch(socket.joins, topic) do
      :error ->
        {:error, :never_joined}

      {:ok, %{status: already_joined}}
      when already_joined in [:requested, :joined] ->
        {:ok, socket}

      {:ok, %{status: :closed} = prior_join} ->
        %Commands.JoinTopic{
          socket: socket,
          topic: topic,
          payload: params || prior_join.params
        }
        |> CommandRouter.route_command()

        {:ok, socket}
    end
  end

  @doc """
  Requests that the given topic be left

  Note that like joining, leaving is an asynchronous request and can be awaited
  with `await_leave/3`.

  Also similar to `join/3`, `leave/2` is idempotent and will not raise an error
  if the provided topic is not currently joined.

  ## Examples

      iex> {:ok, socket} = leave(socket, "room:lobby") |> await_leave("rooms:lobby")
      iex> join(socket, "rooms:specific")
  """
  @doc since: "1.0.0"
  @spec leave(socket :: Socket.t(), topic :: String.t()) :: Socket.t()
  def leave(%Socket{} = socket, topic) when is_binary(topic) do
    if Socket.joined?(socket, topic) do
      %Commands.LeaveTopic{socket: socket, topic: topic}
      |> CommandRouter.route_command()
    end

    socket
  end

  @doc """
  Requests that a message be pushed on the websocket connection

  A channel has the ability to reply directly to a message, but this reply
  is asynchronous. Handle replies using the `c:handle_reply/3`
  callback or by awaiting them synchronously with `await_reply/2`.

  Although this request to the remote server is asynchronous, the call to the
  transport process to transmit the push is synchronous and will exert
  back-pressure on calls to `push/4`, as `push/4` blocks until the message
  has been sent by the transport.

  If you are pushing especially large messages, you may need to adjust the
  `timeout` argument so that the GenServer call does not exit with `:timeout`.
  The default value is `5_000` msec (5 seconds).

  A phoenix channel may decide to reply to a message sent with `push/2`. In
  order to link push requests to their replies, store the `ref` string returned
  from the call to `push/4` and match on it in `c:handle_reply/3`.

  ## Examples

      @impl Slipstream
      def handle_join(:success, _response, state) do
        {:ok, hello_request} = push(socket, "rooms:lobby", "new:msg", %{user: 1, body: "hello"})

        {:ok, Map.put(state, :hello_request, hello_request)}
      end

      @impl Slipstream
      def handle_reply(ref, reply, %{hello_request: ref} = state) do
        IO.inspect(reply, label: "nice, a response.")

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @spec push(
          socket :: Socket.t(),
          topic :: String.t(),
          event :: String.t(),
          params :: json_serializable(),
          timeout :: timeout()
        ) :: {:ok, push_reference()} | {:error, reason :: term()}
  def push(
        %Socket{} = socket,
        topic,
        event,
        params,
        timeout \\ @default_timeout
      )
      when is_binary(topic) and is_binary(event) do
    if Socket.joined?(socket, topic) do
      %Commands.PushMessage{
        socket: socket,
        topic: topic,
        event: event,
        payload: params,
        timeout: timeout
      }
      |> CommandRouter.route_command()
    else
      {:error, :not_joined}
    end
  end

  @doc """
  Pushes, raising if the topic is not joined or if the channel is dead

  Same as `push/4`, but raises in cases of failure.

  This can be useful for pipeing into `await_reply/2`

  ## Examples

      iex> {:ok, result} = push!(socket, "rooms:lobby", "msg:new", params) |> await_reply()
      {:ok, %{"created?" => true}}
  """
  @doc since: "1.0.0"
  @spec push!(
          socket :: Socket.t(),
          topic :: String.t(),
          event :: String.t(),
          params :: json_serializable()
        ) :: push_reference()
  def push!(socket, topic, event, params) do
    case push(socket, topic, event, params) do
      {:ok, ref} ->
        ref

      {:error, reason} ->
        raise "could not push!/4 message: #{inspect(reason)}"
    end
  end

  # --- await functionality

  @doc """
  Awaits a pending connection request synchronously
  """
  @doc since: "1.0.0"
  @spec await_connect(socket :: Socket.t()) ::
          {:ok, Socket.t()} | {:error, term()}
  @spec await_connect(socket :: Socket.t(), timeout()) ::
          {:ok, Socket.t()} | {:error, term()}
  def await_connect(socket, timeout \\ @default_timeout) do
    receive do
      {:__slipstream__, %Events.ChannelConnected{} = event} ->
        {:ok, Socket.apply_event(socket, event)}

      {:__slipstream__, %Events.ChannelConnectFailed{} = event} ->
        {:error, Events.ChannelConnectFailed.to_reason(event)}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Awaits a pending connection request synchronously, raising on failure
  """
  @doc since: "1.0.0"
  @spec await_connect!(socket :: Socket.t()) :: Socket.t()
  @spec await_connect!(socket :: Socket.t(), timeout()) :: Socket.t()
  def await_connect!(socket, timeout \\ @default_timeout) do
    case await_connect(socket, timeout) do
      {:ok, socket} -> socket
      {:error, reason} when is_atom(reason) -> exit(reason)
      {:error, reason} -> raise "Could not await connection: #{inspect(reason)}"
    end
  end

  @doc """
  Awaits a pending join request synchronously
  """
  @doc since: "1.0.0"
  @spec await_join(socket :: Socket.t(), topic :: String.t()) ::
          {:ok, Socket.t()} | {:error, term()}
  @spec await_join(socket :: Socket.t(), topic :: String.t(), timeout()) ::
          {:ok, Socket.t()} | {:error, term()}
  def await_join(socket, topic, timeout \\ @default_timeout)
      when is_binary(topic) do
    receive do
      {:__slipstream__, %Events.TopicJoinSucceeded{topic: ^topic} = event} ->
        {:ok, Socket.apply_event(socket, event)}

      {:__slipstream__, %Events.TopicJoinFailed{topic: ^topic} = event} ->
        {:error, Events.TopicJoinFailed.to_reason(event)}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Awaits a join request synchronously, raising on failure
  """
  @doc since: "1.0.0"
  @spec await_join!(socket :: Socket.t()) :: Socket.t()
  @spec await_join!(socket :: Socket.t(), timeout()) :: Socket.t()
  def await_join!(socket, timeout \\ @default_timeout) do
    case await_join(socket, timeout) do
      {:ok, socket} -> socket
      {:error, reason} when is_atom(reason) -> exit(reason)
      {:error, reason} -> raise "Could not await join: #{inspect(reason)}"
    end
  end

  @doc """
  Awaits a leave request synchronously
  """
  @doc since: "1.0.0"
  @spec await_leave(socket :: Socket.t(), topic :: String.t()) ::
          {:ok, Socket.t()} | {:error, term()}
  @spec await_leave(socket :: Socket.t(), topic :: String.t(), timeout()) ::
          {:ok, Socket.t()} | {:error, term()}
  def await_leave(socket, topic, timeout \\ @default_timeout)
      when is_binary(topic) do
    receive do
      {:__slipstream__, %Events.TopicLeft{topic: ^topic} = event} ->
        {:ok, Socket.apply_event(socket, event)}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Awaits a leave request synchronously, raising on failure
  """
  @doc since: "1.0.0"
  @spec await_leave!(socket :: Socket.t()) :: Socket.t()
  @spec await_leave!(socket :: Socket.t(), timeout()) :: Socket.t()
  def await_leave!(socket, timeout \\ @default_timeout) do
    case await_leave(socket, timeout) do
      {:ok, socket} -> socket
      {:error, reason} when is_atom(reason) -> exit(reason)
      {:error, reason} -> raise "Could not await leave: #{inspect(reason)}"
    end
  end

  @doc """
  Awaits the server's response to a message
  """
  @doc since: "1.0.0"
  @spec await_reply(push_reference()) :: reply() | {:error, :timeout}
  @spec await_reply(push_reference(), timeout()) :: reply() | {:error, :timeout}
  def await_reply(push_reference, timeout \\ @default_timeout)

  def await_reply({topic, ref}, timeout) do
    receive do
      {:__slipstream__, %Events.ReplyReceived{ref: ^ref, topic: ^topic} = event} ->
        Events.ReplyReceived.to_reply(event)
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Awaits the server's response to a message, exiting on timeout

  See `await_reply/2` for more information.
  """
  @doc since: "1.0.0"
  @spec await_reply!(push_reference()) :: reply()
  @spec await_reply!(push_reference(), timeout()) :: reply()
  def await_reply!(push_reference, timeout \\ @default_timeout) do
    case await_reply(push_reference, timeout) do
      {:error, :timeout} -> exit(:timeout)
      reply -> reply
    end
  end

  defmacro __using__(opts) do
    quote location: :keep do
      def child_spec(init_arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }
        |> Supervisor.child_spec(unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1

      import Slipstream

      @behaviour Slipstream

      @impl Slipstream
      def handle_info({:__slipstream__, event}, socket) do
        case Slipstream.__handle_event__(event, socket) do
          {:ok, socket} -> {:noreply, socket}
          {:ok, socket, other_stuff} -> {:noreply, socket, other_stuff}
          {:stop, _reason, _socket} = stop -> stop
        end
      end
    end
  end

  def __handle_event__(event, socket) do
    Slipstream.Callback.dispatch(event, Socket.apply_event(socket, event))
  end
end
