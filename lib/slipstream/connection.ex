defmodule Slipstream.Connection do
  @moduledoc false

  # the Connection _is_ the socket client
  # Connection interfaces with :gun and any module that implements the
  # Slipstream behaviour to offer websocket client functionality

  use GenServer

  alias __MODULE__.State
  alias Phoenix.Socket.Message

  import __MODULE__.Impl
  import State, only: [callback: 3]

  def start_link(callback_module, init_arg, gen_server_options) do
    GenServer.start_link(
      __MODULE__,
      {callback_module, init_arg},
      gen_server_options
    )
  end

  @impl GenServer
  def init({callback_module, init_arg}) do
    state = %State{implementor: callback_module}

    callback(state, :init, [init_arg])
    |> map_genserver_return(state)
  end

  @impl GenServer
  def handle_info({:connect, configuration}, state) do
    uri = configuration.uri

    state = %State{state | connection_configuration: configuration}

    case :gun.open(to_charlist(uri.host), uri.port) do
      {:ok, conn} ->
        stream_ref =
          :gun.ws_upgrade(
            conn,
            to_charlist(uri.path || "/"),
            configuration.headers
          )

        {:noreply,
         %State{state | connection_conn: conn, connection_ref: stream_ref}}

      e ->
        raise e
    end
  end

  def handle_info(:reconnect, state) do
    state = State.increment_reconnect_counter(state)

    Process.send_after(
      self(),
      {:connect, state.connection_configuration},
      retry_time(:reconnect, state)
    )

    {:noreply, state}
  end

  def handle_info({:join, topic, params}, state) do
    state =
      %State{state | topic: topic, join_params: params}
      |> State.reset_refs()

    push_message(%{event: "phx_join", topic: topic, payload: params}, state)

    {:noreply, state}
  end

  def handle_info(:rejoin, state) do
    handle_info({:rejoin, state.join_params}, state)
  end

  def handle_info({:rejoin, params}, state) do
    state = State.increment_rejoin_counter(state)

    Process.send_after(
      self(),
      {:join, state.topic, params},
      retry_time(:rejoin, state)
    )

    {:noreply, state}
  end

  def handle_info(:send_heartbeat, state) do
    # TODO if there's a heartbeat_ref here, we're fucked

    state =
      state
      |> State.put_next_ref()
      |> State.copy_ref_to_heartbeat()

    push_heartbeat(state)

    {:noreply, state}
  end

  # this match on the `conn` var helps identify unclosed connections (leaks)
  # during development but should probably be removed when this library is
  # ready to ship, as we don't want implementors having to handle gun messages
  # _at all_ TODO
  def handle_info({:gun_up, conn, _http}, %State{connection_conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info({:gun_down, conn, :ws, :closed, [], []}, %State{connection_conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:gun_upgrade, conn, stream_ref, ["websocket"], resp_headers},
        %State{connection_conn: conn, connection_ref: stream_ref} = state
      ) do
    # use for telemetry?
    _resp_headers = resp_headers

    state =
      state
      |> State.reset_reconnect_try_counter()
      |> State.reset_heartbeat()

    :timer.send_interval(
      state.connection_configuration.heartbeat_interval_msec,
      :send_heartbeat
    )

    callback(state, :handle_connect, [state.implementor_state])
    |> map_novel_callback_return(state)
  end

  def handle_info(
        {:gun_ws, conn, stream_ref, message},
        %State{connection_conn: conn, connection_ref: stream_ref} = state
      ) do
    message
    |> decode_message(state)
    |> handle_message(state)
  end

  def handle_info(unknown_message, state) do
    callback(state, :handle_info, [unknown_message, state.implementor_state])
    |> map_genserver_return(state)
  end

  # ---

  defp handle_message(:ping, state) do
    :gun.ws_send(state.connection_conn, :pong)

    {:noreply, state}
  end

  defp handle_message(:pong, state) do
    {:noreply, state}
  end

  defp handle_message({:close, _timeout, ""}, state) do
    state =
      %State{state | connection_ref: nil}
      |> State.cancel_heartbeat_timer()

    :gun.close(state.connection_conn)

    callback(state, :handle_disconnect, [
      :heartbeat_timeout,
      state.implementor_state
    ])
    |> map_novel_callback_return(state)
  end

  defp handle_message(
         %Message{
           topic: topic,
           event: "phx_reply",
           payload: %{"response" => response, "status" => status},
           ref: join_ref
         },
         %State{topic: topic, join_ref: join_ref} = state
       ) do
    {status, state} =
      case status do
        "ok" -> {:success, State.reset_rejoin_try_counter(state)}
        "error" -> {:failure, state}
      end

    callback(state, :handle_join, [status, response, state.implementor_state])
    |> map_novel_callback_return(state)
  end

  defp handle_message(
         %Message{
           topic: topic,
           event: "phx_error",
           payload: payload,
           ref: join_ref
         },
         %State{topic: topic, join_ref: join_ref} = state
       ) do
    callback(state, :handle_channel_close, [payload, state.implementor_state])
    |> map_novel_callback_return(state)
  end

  defp handle_message(
         %Message{
           topic: topic,
           event: "phx_error",
           payload: payload,
           ref: message_ref
         },
         %State{topic: topic} = state
       ) do
    _todo_something_with_this_ref = message_ref

    callback(state, :handle_message, [
      {:error, payload},
      state.implementor_state
    ])
    |> map_novel_callback_return(state)
  end

  # heartbeat ack by remote server
  defp handle_message(
         %Message{
           topic: "phoenix",
           event: "phx_reply",
           payload: %{"response" => %{}, "status" => "ok"},
           ref: heartbeat_ref
         },
         %State{heartbeat_ref: heartbeat_ref} = state
       ) do
    {:noreply, State.reset_heartbeat(state)}
  end
end
