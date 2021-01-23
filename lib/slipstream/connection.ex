defmodule Slipstream.Connection do
  @moduledoc false

  # the Connection _is_ the socket client
  # Connection interfaces with :gun and any module that implements the
  # Slipstream behaviour to offer websocket client functionality

  use GenServer

  alias __MODULE__.State

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
    uri = Keyword.fetch!(configuration, :uri)

    state = %State{state | connection_configuration: configuration}

    case :gun.open(to_charlist(uri.host), uri.port) do
      {:ok, conn} ->
        stream_ref = :gun.ws_upgrade(conn, to_charlist(uri.path || "/"))

        {:noreply,
         %State{state | connection_conn: conn, connection_ref: stream_ref}}

      e ->
        raise e
    end
  end

  def handle_info({:join, topic, params}, state) do
    state =
      %State{state | topic: topic, join_ref: 0, current_ref: 0}

    push_message(%{event: "phx_join", topic: topic, payload: params}, state)

    {:noreply, state}
  end

  def handle_info({:gun_up, conn, _http}, %State{connection_conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:gun_upgrade, conn, stream_ref, ["websocket"], resp_headers},
        %State{connection_conn: conn, connection_ref: stream_ref} = state
      ) do
    # use for telemetry?
    _resp_headers = resp_headers

    callback(state, :handle_connect, [state.implementor_state])
    |> map_genserver_return(state)
  end

  def handle_info({:gun_ws, conn, stream_ref, message}, %State{connection_conn: conn, connection_ref: stream_ref} = state) do
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

  defp handle_message(%{"topic" => topic, "event" => "phx_reply", "payload" => %{"response" => response, "status" => status}, "ref" => 0}, %State{topic: topic} = state) do
    success? =
      case status do
        "ok" -> true
        "error" -> false
      end

    callback(state, :handle_join, [success?, response, state.implementor_state])
    |> map_genserver_return(state)
  end
end
