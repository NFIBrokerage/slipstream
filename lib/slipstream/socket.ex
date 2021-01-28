defmodule Slipstream.Socket do
  @moduledoc """
  A datastructure representing a potential websocket client connection
  """

  import Kernel, except: [send: 2, pid: 1]

  alias __MODULE__.Join
  alias Slipstream.Events

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: [:assigns]}
  end

  defstruct [
    :channel_pid,
    :socket_pid,
    :channel_config,
    :response_headers,
    joins: %{},
    assigns: %{}
  ]

  @typedoc """
  The socket datastructure
  """
  @typedoc since: "1.0.0"
  @type t :: %__MODULE__{
          channel_pid: nil | pid(),
          socket_pid: pid(),
          channel_config: Slipstream.Configuration.t() | nil,
          assigns: map(),
          joins: %{String.t() => %Join{}}
        }

  @doc false
  @spec new() :: t()
  def new do
    %__MODULE__{socket_pid: self()}
  end

  @doc """
  Adds key-value pairs to socket assigns

  Behaves the same as `Phoenix.Socket.assign/3`

  ## Examples

      iex> assign(socket, :key, :value)
      iex> assign(socket, key: :value)
  """
  # and indeed the implementation is just about the same as well.
  # we can't defdelegate/2 though because the socket module is different
  # (hence the struct doesn't match)
  @doc since: "1.0.0"
  @spec assign(t(), Keyword.t()) :: t()
  @spec assign(t(), key :: atom(), value :: any()) :: t()
  def assign(%__MODULE__{} = socket, key, value) when is_atom(key) do
    assign(socket, [{key, value}])
  end

  def assign(%__MODULE__{} = socket, attrs)
      when is_list(attrs) or is_map(attrs) do
    %__MODULE__{socket | assigns: Map.merge(socket.assigns, Map.new(attrs))}
  end

  @doc """
  Checks if a channel is currently joined

  ## Examples

      iex> joined?(socket, "room:lobby")
      true
  """
  @doc since: "1.0.0"
  @spec joined?(t(), topic :: String.t()) :: boolean()
  def joined?(%__MODULE__{} = socket, topic) when is_binary(topic) do
    join_status(socket, topic) == :joined
  end

  @doc """
  Checks the status of a join request

  When a join is requested with `Slipstream.join/3`, the join request is
  considered to be in the `:requested` state. Once the topic is successfully
  joined, it is considered `:joined` until closed. If there is a failure to
  join the topic, if the topic crashes, or if the topic is left after being
  joined, the status of the join is considered `:closed`. Finally, if a topic
  has not been requested in a join so far for a socket, the status is `nil`.

  Notably, the status of a join will not automatically change to `:joined` once
  the remote server replies with successful join. Either the join must be
  awaited with `Slipstream.await_join/2` or the status may be checked later
  in the `c:Slipstream.handle_join/3` callback.

  ## Examples

      iex> socket = join(socket, "room:lobby")
      iex> join_status(socket, "room:lobby")
      :requested
      iex> {:ok, socket, _join_response} = await_join(socket, "room:lobby")
      iex> join_status(socket, "room:lobby")
      :joined
  """
  @doc since: "1.0.0"
  @spec join_status(t(), topic :: String.t()) ::
          :requested | :joined | :closed | nil
  def join_status(%__MODULE__{} = socket, topic) when is_binary(topic) do
    case Map.fetch(socket.joins, topic) do
      {:ok, %Join{status: status}} -> status
      :error -> nil
    end
  end

  @doc """
  Checks if a socket is connected to a remote websocket host

  ## Examples

      iex> socket = connect(socket, uri: "ws://example.org")
      iex> socket = await_connect!(socket)
      iex> connected?(socket)
      true
  """
  @doc since: "1.0.0"
  @spec connected?(t()) :: boolean()
  def connected?(%__MODULE__{} = socket),
    do: socket |> channel_pid() |> is_pid()

  @doc """
  Gets the process ID of the connection

  The slipstream implementor module is not the same process as the GenServer
  which interfaces with the remote server for websocket communication. This
  other process, the Slipstream.Connection process, interfaces with `:gun`
  and communicates with the implementor module by puassing messages (mostly
  with `Kernel.send/2`.

  It can be useful to have access to this pid for niche purposes, like
  sending a fake disconnect message or for debugging (e.g. with
  `:sys.get_state/1`)

  ## Examples

      iex> Slipstream.Socket.channel_pid(socket)
      #PID<0.1.2>
  """
  @doc since: "1.0.0"
  @spec channel_pid(t()) :: pid() | nil
  def channel_pid(%__MODULE__{channel_pid: pid}) do
    if is_pid(pid) and Process.alive?(pid), do: pid, else: nil
  end

  ## helper functions for implementing Slipstream

  @doc false
  def send(%__MODULE__{} = socket, message) do
    if pid = channel_pid(socket), do: Kernel.send(pid, message)

    socket
  end

  @doc false
  def call(%__MODULE__{} = socket, message, timeout) do
    if pid = channel_pid(socket) do
      {:ok, GenServer.call(pid, message, timeout)}
    else
      {:error, :not_connected}
    end
  end

  @doc false
  def put_join_config(%__MODULE__{} = socket, topic, params) do
    join = Join.new(topic, params)

    %__MODULE__{socket | joins: Map.put_new(socket.joins, topic, join)}
  end

  # potentially changes a socket by applying an event to it
  @doc false
  @spec apply_event(t(), struct()) :: t()
  def apply_event(socket, event)

  def apply_event(socket, %Events.ChannelConnected{} = event) do
    %__MODULE__{socket | channel_pid: event.pid, channel_config: event.config}
  end

  def apply_event(socket, %Events.TopicJoinSucceeded{topic: topic}) do
    put_in(socket, [Access.key(:joins), topic, Access.key(:status)], :joined)
  end

  def apply_event(socket, %event{topic: topic})
      when event in [
             Events.TopicLeft,
             Events.TopicJoinFailed,
             Events.TopicJoinClosed
           ] do
    put_in(socket, [Access.key(:joins), topic, Access.key(:status)], :closed)
  end

  def apply_event(socket, _event), do: socket
end
