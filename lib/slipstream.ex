defmodule Slipstream do
  @moduledoc """
  A websocket client for Phoenix channels

  Slipstream is a websocket client for connection to `Phoenix.Channel`s.
  Slipstream is a bit different from existing websocket implementations in that:

  - it's backed by `:gun` instead of `:websocket_client`
  - it emits telemetry (via `:telemetry`)
  """

  import Slipstream.Connection.Impl, only: [next_ref: 0]

  @typedoc """
  Any data structure capable of being serialized as JSON

  Any argument typed as `t:Slipstream.json_serializable/0` must be able to
  be encoded with the JSON parser passed in configuration. See
  `Slipstream.Configuration`.
  """
  @typedoc since: "1.0.0"
  @type json_serializable :: term()

  # the family of GenServer-wrapping callbacks

  @doc """
  Invoked when the slipstream process in started

  See `c:GenServer.init/1` for more information.

  This callback is a good place to request connection with `connect/1`:

  ```elixir
  @impl Slipstream
  def init(args) do
    Application.fetch_env!(:my_app, __MODULE__) |> connect!()

    {:ok, args}
  end
  ```
  """
  @doc since: "1.0.0"
  @callback init(init_arg :: any()) ::
              {:ok, any()}
              | {:ok, state, timeout() | :hibernate | {:continue, term()}}
              | :ignore
              | {:stop, reason :: any()}
            when state: any()

  @doc """
  Invoked when a slipstream process receives a message

  Behaves the same as `c:GenServer.handle_info/2`
  """
  @doc since: "1.0.0"
  @callback handle_info(msg :: term(), state :: term()) ::
              {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

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
              :success | :failure,
              response :: json_serializable(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a message is received on the websocket connection

  TODO docs on replying, implement replies

  ## Examples

      @impl Slipstream
      def handle_message(event, message, state) do
        IO.inspect({event, message}, label: "message received")

        {:noreply, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_message(
              event :: String.t(),
              message :: any(),
              state :: term()
            ) ::
              {:reply, reply, new_state}
              | {:reply, reply, new_state,
                 timeout() | :hibernate | {:continue, term()}}
              | {:noreply, new_state}
              | {:noreply, new_state,
                 timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason, reply, new_state}
              | {:stop, reason, new_state}
            when reply: term(), new_state: term(), reason: term()

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
              ref :: String.t(),
              message :: any(),
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
      def handle_channel_close(_message, state) do
        rejoin()

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @callback handle_channel_close(reason :: term(), state :: term()) ::
              {:ok, new_state}
              | {:stop, stop_reason :: term(), new_state}
            when new_state: term()

  @optional_callbacks init: 1,
                      handle_info: 2,
                      terminate: 2,
                      handle_connect: 1,
                      handle_disconnect: 2,
                      handle_join: 3,
                      handle_message: 3,
                      handle_reply: 3,
                      handle_channel_close: 2

  @doc """
  Starts a slipstream client process

  `module` is used to invoke the `Slipstream` callbacks. `init_arg` will be
  the argument passed to `c:Slipstream.init/1`. `options` will be passed to
  the argument by the same name in `GenServer.start_link/3`.
  """
  @spec start_link(module(), any(), GenServer.options()) :: GenServer.on_start()
  def start_link(module, init_arg, options \\ []) do
    Slipstream.Connection.start_link(
      module,
      init_arg,
      options
    )
  end

  @doc """
  Requests connection to the remote endpoint

  `opts` are passed to `Slipstream.Configuration.validate/1` before sending.

  Note that this request for connection is asynchronous. A return value of
  `:ok` does not mean that a connection has successfully been established.

  ## Examples

      connect(uri: "ws://localhost:4000/socket/websocket")
  """
  @doc since: "1.0.0"
  @spec connect(server :: pid, opts :: Keyword.t()) ::
          :ok | {:error, %NimbleOptions.ValidationError{}}
  def connect(server \\ self(), opts) do
    case Slipstream.Configuration.validate(opts) do
      {:ok, configuration} ->
        send(server, {:connect, configuration})

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as `connect/2` but raises on configuration validation error
  """
  @doc since: "1.0.0"
  @spec connect!(server :: pid(), opts :: Keyword.t()) :: :ok
  def connect!(server \\ self(), opts) do
    configuration = Slipstream.Configuration.validate!(opts)

    send(server, {:connect, configuration})

    :ok
  end

  @doc """
  Request reconnection given the last-used connection configuration

  Note that when `reconnect/1` is used to re-connect instead of `connect/2`
  (or `connect!/2`), the slipstream process will attempt to reconnect with
  a retry mechanism with backoff. The process will wait an interval between
  reconnection attempts following the list of milliseconds provided in the
  `:reconnect_after_msec` key of configuration passed to `connect/2` (or
  `connect!/2`).

  The `c:Slipstream.handle_disconnect/2` callback will be invoked for each
  failure to re-connect, however, so an implementation of that callback which
  will simply retry with backoff can be achieved like so:

  ## Examples

      @impl Slipstream
      def handle_disconnect(_reason, state) do
        reconnect()

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @spec reconnect(server :: pid()) :: :ok
  def reconnect(server \\ self()) do
    send(server, :reconnect)

    :ok
  end

  @doc """
  Requests that a topic be joined in the current connection

  ## Examples

      @impl Slipstream
      def handle_connect(state) do
        join("rooms:lobby", %{user: 1})

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @spec join(topic :: String.t()) :: :ok
  @spec join(topic :: String.t(), params :: json_serializable()) :: :ok
  @spec join(server :: pid(), topic :: String.t()) :: :ok
  @spec join(
          server :: pid(),
          topic :: String.t(),
          params :: json_serializable()
        ) :: :ok
  def join(topic) when is_binary(topic) do
    join(self(), topic, %{})
  end

  def join(server, topic) when is_pid(server) and is_binary(topic) do
    join(server, topic, %{})
  end

  def join(topic, params) when is_binary(topic) do
    join(self(), topic, params)
  end

  def join(server, topic, params) when is_pid(server) and is_binary(topic) do
    send(server, {:join, topic, params})

    :ok
  end

  @doc """
  Requests that the last requested channel be joined

  If `params` is not provided, the previously used value will be sent.

  ## Dealing with crashes

  When attempting to re-join a disconnected topic with `rejoin/2`, the
  slipstream process will attempt to use backoff governed by the
  `:rejoin_after_msec` list in configuration passed to `connect/2` (or
  `connect!/2`).

  The `c:Slipstream.handle_channel_close/2` callback will be invoked with
  the for each crash, however, so a minimal implementation of that callback
  which achieves the backoff retry is like so:

  ## Examples

      @impl Slipstream
      def handle_channel_close(_reason, state) do
        rejoin()

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @spec rejoin() :: :ok
  @spec rejoin(server :: pid()) :: :ok
  @spec rejoin(params :: json_serializable()) :: :ok
  @spec rejoin(server :: pid(), params :: json_serializable()) :: :ok
  def rejoin do
    rejoin(self())
  end

  def rejoin(server) when is_pid(server) do
    send(server, :rejoin)

    :ok
  end

  def rejoin(params) do
    rejoin(self(), params)
  end

  def rejoin(server, params) when is_pid(server) do
    send(server, {:rejoin, params})

    :ok
  end

  @doc """
  Requests that a message be pushed on the websocket connection

  A channel has the ability to reply directly to a message, but this reply
  is asynchronous. Handle replies using the `c:Slipstream.handle_reply/3`
  callback.

  Note that `push/2` cannot be called from another process. It must be
  called from the slipstream process.

  A phoenix channel may decide to reply to a message sent with `push/2`. In
  order to link push requests to their replies, store the `ref` string returned
  from the call to `push/2` and match on it in `c:Slipstream.handle_reply/3`.

  ## Examples

      @impl Slipstream
      def handle_join(:success, _response, state) do
        hello_request = push("new:msg", %{user: 1, body: "hello"})

        {:ok, Map.put(state, :hello_request, hello_request)}
      end

      @impl Slipstream
      def handle_reply(ref, reply, %{hello_request: ref} = state) do
        IO.inspect(reply, label: "nice, a response.")

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  @spec push(event :: String.t(), params :: json_serializable()) :: String.t()
  def push(event, params) do
    ref = next_ref()

    send(self(), {:push, ref, event, params})

    ref
  end
end
