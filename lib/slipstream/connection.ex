defmodule Slipstream.Connection do
  @moduledoc false

  # the Connection _is_ the socket client
  # Connection interfaces with Mint.WebSocket and any module that implements the
  # Slipstream behaviour to offer websocket client functionality

  use GenServer, restart: :temporary

  alias Slipstream.Connection.{State, Pipeline, Telemetry}

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl GenServer
  def init(%Slipstream.Commands.OpenConnection{
        socket: %Slipstream.Socket{socket_pid: socket_pid},
        config: config
      }) do
    %State{} = initial_state = State.new(config, socket_pid)

    metadata = Telemetry.begin(initial_state)
    state = %{initial_state | metadata: metadata}

    {:ok, state, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    Pipeline.handle(:connect, state)
  end

  @impl GenServer
  def handle_info(message, state) do
    Pipeline.handle(message, state)
  end

  @impl GenServer
  def handle_call(message, _from, state) do
    Pipeline.handle(message, state)
  end

  @impl GenServer
  def terminate(reason, state) do
    Telemetry.conclude(state, reason)

    state
  end
end
