defmodule Slipstream.Connection do
  @moduledoc false

  # the Connection _is_ the socket client
  # Connection interfaces with :gun and any module that implements the
  # Slipstream behaviour to offer websocket client functionality

  use GenServer, restart: :temporary

  import __MODULE__.Impl, only: [route_event: 2]
  import Slipstream.Commands, only: [command: 1]
  alias __MODULE__.{Impl, State}
  alias Slipstream.{Events, Commands}

  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl GenServer
  def init(%Commands.OpenConnection{
        socket: %Slipstream.Socket{socket_pid: socket_pid},
        config: config
      }) do
    {:ok, %State{socket_pid: socket_pid, config: config}, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    state = %State{state | socket_ref: Process.monitor(state.socket_pid)}

    {:noreply, Impl.connect(state)}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, socket_ref, :process, socket_pid, reason},
        %State{socket_ref: socket_ref, socket_pid: socket_pid} = state
      ) do
    {:stop, reason, state}
  end

  # this match on the `conn` var helps identify unclosed connections (leaks)
  # during development but should probably be removed when this library is
  # ready to ship, as we don't want implementors having to handle gun messages
  # _at all_ TODO
  def handle_info({:gun_up, conn, _http}, %State{conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:gun_upgrade, conn, stream_ref, ["websocket"], resp_headers},
        %State{conn: conn, stream_ref: stream_ref} = state
      ) do
    state =
      state
      |> State.reset_reconnect_try_counter()
      |> State.reset_heartbeat()

    :timer.send_interval(
      state.config.heartbeat_interval_msec,
      %Commands.SendHeartbeat{}
    )

    route_event state, %Events.ChannelConnected{
      pid: self(),
      config: state.config,
      response_headers: resp_headers
    }

    {:noreply, state}
  end

  def handle_info(
        {:gun_down, conn, :ws, :closed, [], []},
        %State{conn: conn} = state
      ) do
    route_event state, %Events.ChannelClosed{reason: :closed_by_remote_server}

    {:noreply, state}
  end

  def handle_info(
        {:gun_ws, conn, stream_ref, message},
        %State{conn: conn, stream_ref: stream_ref} = state
      ) do
    event = message |> Impl.decode_message(state) |> Events.map(state)

    state
    |> State.apply_event(event)
    |> Impl.handle_event(event)
  end

  def handle_info(command(cmd), state) do
    state
    |> State.apply_command(cmd)
    |> Impl.handle_command(cmd)
  end

  def handle_info(unknown_message, state) do
    Logger.error("unknown message #{inspect(unknown_message)}")

    {:noreply, state}
  end
end
