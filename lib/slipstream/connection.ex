defmodule Slipstream.Connection do
  @moduledoc false

  # the Connection _is_ the socket client
  # Connection interfaces with :gun and any module that implements the
  # Slipstream behaviour to offer websocket client functionality

  use GenServer, restart: :temporary

  import __MODULE__.Impl, only: [route_event: 2]
  alias Phoenix.Socket.Message
  alias __MODULE__.{Impl, State}
  alias Slipstream.{Events, Commands}

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl GenServer
  def init(%Commands.OpenConnection{socket: %Slipstream.Socket{socket_pid: socket_pid}, config: config}) do
    {:ok, %State{socket_pid: socket_pid, config: config}, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    state = %State{state | socket_ref: Process.monitor(state.socket_pid)}

    {:noreply, Impl.connect(state)}
  end

  @impl GenServer
  def handle_info({:DOWN, socket_ref, :process, socket_pid, reason}, %State{socket_ref: socket_ref, socket_pid: socket_pid} = state) do
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
    message
    |> Impl.decode_message(state)
    |> IO.inspect(label: "incoming message")

    {:noreply, state}
  end

  def handle_info(%Commands.SendHeartbeat{}, state) do
    # TODO disconnect when there is a heartbeat_ref in state here

    state = State.next_heartbeat_ref(state)

    Impl.push_heartbeat(state)

    {:noreply, state}
  end

  def handle_info(%Commands.PushMessage{} = cmd, state) do
    {ref, state} = State.next_ref(state)

    Impl.push_message(
      %Message{
        topic: cmd.topic,
        event: cmd.event,
        payload: cmd.payload,
        ref: ref
      },
      state
    )

    {:reply, ref, state}
  end

  def handle_info(%_{} = cmd, state) do
    IO.inspect(cmd, label: "connection heard cmd")
    {:noreply, state}
  end

  def handle_info(unknown_message, state) do
    IO.inspect(unknown_message, label: "unknown message in #{inspect(__MODULE__)}")

    {:noreply, state}
  end

  # TODO map join crash to event
  # defp handle_message(
         # %Message{
           # topic: topic,
           # event: "phx_error",
           # payload: payload,
           # ref: join_ref
         # },
         # %State{topic: topic, join_ref: join_ref} = state
       # ) do
    # state = %State{state | join_ref: nil}

    # callback(state, :handle_channel_close, [payload])
    # |> map_novel_callback_return(state)
  # end
end
