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
    state = %State{implementor: callback_module, implementor_state: init_arg}

    callback(state, :init, [])
    |> map_genserver_return(state)
  end

  @impl GenServer
  def handle_info({:connect, configuration}, state) do
    uri = configuration.uri

    state = %State{state | connection_configuration: configuration}

    {:ok, conn} =
      :gun.open(
        to_charlist(uri.host),
        uri.port,
        configuration.gun_open_options
      )

    stream_ref =
      :gun.ws_upgrade(
        conn,
        path(uri),
        configuration.headers
      )

    {:noreply,
     %State{state | connection_conn: conn, connection_ref: stream_ref}}
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
    ref = next_ref() |> to_string()

    state = %State{state | topic: topic, join_params: params, join_ref: ref}

    push_message(
      %Message{
        event: "phx_join",
        topic: topic,
        payload: params,
        join_ref: ref,
        ref: ref
      },
      state
    )

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
    # that means the server has not sent a reply to the last heartbeat we sent
    # it

    state = %State{state | heartbeat_ref: next_ref()}

    push_message(
      %Message{
        event: "heartbeat",
        topic: "phoenix",
        ref: state.heartbeat_ref,
        payload: %{}
      },
      state
    )

    {:noreply, state}
  end

  def handle_info({:push, ref, event, payload}, state) do
    push_message(
      %Message{
        topic: state.topic,
        event: event,
        payload: payload,
        ref: ref,
        join_ref: nil
      },
      state
    )

    {:noreply, state}
  end

  # this match on the `conn` var helps identify unclosed connections (leaks)
  # during development but should probably be removed when this library is
  # ready to ship, as we don't want implementors having to handle gun messages
  # _at all_ TODO
  def handle_info({:gun_up, conn, _http}, %State{connection_conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:gun_down, conn, :ws, :closed, [], []},
        %State{connection_conn: conn} = state
      ) do
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

    callback(state, :handle_connect, [])
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
    callback(state, :handle_info, [unknown_message])
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
      %State{state | connection_ref: nil, join_ref: nil}
      |> State.cancel_heartbeat_timer()

    :gun.close(state.connection_conn)

    callback(state, :handle_disconnect, [:closed_by_remote_server])
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

    callback(state, :handle_join, [status, response])
    |> map_novel_callback_return(state)
  end

  defp handle_message(
         %Message{
           topic: topic,
           event: "phx_reply",
           payload: %{"response" => response, "status" => status},
           ref: ref
         },
         %State{topic: topic} = state
       )
       when ref != nil do
    callback(state, :handle_reply, [ref, {String.to_atom(status), response}])
    |> map_novel_callback_return(state)
  end

  defp handle_message(
         %Message{
           topic: topic,
           event: event,
           payload: payload,
           ref: ref
         },
         %State{topic: topic} = state
       )
       when ref == nil do
    callback(state, :handle_message, [event, payload])
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
    state = %State{state | join_ref: nil}

    callback(state, :handle_channel_close, [payload])
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
