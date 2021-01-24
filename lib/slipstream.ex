defmodule Slipstream do
  @moduledoc """
  A websocket client for Phoenix channels

  Slipstream is a websocket client for connection to `Phoenix.Channel`s.
  Slipstream is a bit different from existing websocket implementations in that:

  - it's backed by `:gun` instead of `:websocket_client`
  - it emits telemetry (via `:telemetry`)
  """

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
  @callback init(any()) ::
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
              response :: map() | binary() | any(),
              state :: term()
            ) ::
              {:ok, new_state}
              | {:stop, reason :: term(), new_state}
            when new_state: term()

  @doc """
  Invoked when a message is received on the websocket connection

  ## Examples

      @impl Slipstream
      def handle_message(message, state) do
        IO.inspect(message, label: "message received")

        {:ok, state}
      end
  """
  @doc since: "1.0.0"
  # TODO add reply to spec?
  @callback handle_message(
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
                      handle_message: 2,
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
  """
  @doc since: "1.0.0"
  @spec reconnect(server :: pid()) :: :ok
  def reconnect(server \\ self()) do
    send(server, :reconnect)

    :ok
  end

  @doc """
  Requests that a Phoenix.Channel be joined in the current connection

  Note that `params` must be a datastructure capable of being encoded as
  JSON by the parser passed to the connection configuration's `:json_parser`
  option. A failure to encode the message will result in an error.
  """
  @doc since: "1.0.0"
  @spec join(server :: pid(), topic :: String.t(), params :: map()) :: :ok
  def join(server \\ self(), topic, params \\ %{})

  def join(server, topic, params) do
    send(server, {:join, topic, params})

    :ok
  end

  @doc """
  Requests that the last requested channel be joined

  If `params` is not provided, the previously used value will be sent.

  Note that `params` must be a datastructure capable of being encoded as
  JSON by the parser passed to the connection configuration's `:json_parser`
  option. A failure to encode the message will result in an error.
  """
  @doc since: "1.0.0"
  @spec rejoin() :: :ok
  @spec rejoin(server :: pid()) :: :ok
  @spec rejoin(params :: term()) :: :ok
  @spec rejoin(server :: pid(), params :: term()) :: :ok
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

  # ---

  def handle_call(:ping, _from, state) do
    ws_send(
      state.conn,
      %{
        join_ref: "0",
        ref: "1",
        topic: "echo:foo",
        event: "ping",
        payload: %{}
      }
    )

    {:reply, :ok, state}
  end

  defp ws_send(conn, message) do
    :gun.ws_send(conn, {:binary, Jason.encode_to_iodata!(message)})
  end
end
