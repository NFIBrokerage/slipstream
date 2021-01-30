defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State
  alias Phoenix.Socket.Message
  alias Slipstream.{Events, Commands}
  import Slipstream.Signatures, only: [event: 1]
  require Logger

  if Version.match?(System.version(), ">= 1.10.0") do
    @gun Application.compile_env(:slipstream, :gun_client, :gun)
  else
    @gun Application.get_env(:slipstream, :gun_client, :gun)
  end

  @noop_event_types [
    Events.PongReceived,
    Events.HeartbeatAcknowledged
  ]

  @spec connect(%State{}) :: %State{}
  def connect(%State{config: configuration} = state) do
    uri = configuration.uri

    # N.B. I've _never_ seen this match fail
    # if it does, please open an issue
    {:ok, conn} =
      @gun.open(
        to_charlist(uri.host),
        uri.port,
        configuration.gun_open_options
      )

    stream_ref =
      @gun.ws_upgrade(
        conn,
        path(uri),
        configuration.headers
      )

    %State{state | conn: conn, stream_ref: stream_ref}
  end

  @spec route_event(%State{}, event :: struct()) :: term()
  def route_event(%State{socket_pid: pid}, event) do
    send(pid, event(event))
  end

  @spec handle_command(%State{}, command :: struct()) ::
          {:noreply, new_state}
          | {:reply, Slipstream.push_reference(), new_state}
        when new_state: %State{}
  def handle_command(state, command)

  def handle_command(state, %Commands.SendHeartbeat{}) do
    push_heartbeat(state)

    {:noreply, state}
  end

  def handle_command(state, %Commands.CollectGarbage{}) do
    :erlang.garbage_collect(self())

    {:noreply, state}
  end

  def handle_command(state, %Commands.PushMessage{} = cmd) do
    ref = state.current_ref_str

    push_message(
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

  def handle_command(state, %Commands.JoinTopic{} = cmd) do
    push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_join",
        payload: cmd.payload,
        ref: state.current_ref_str,
        join_ref: state.current_ref_str
      },
      state
    )

    {:noreply, state}
  end

  def handle_command(state, %Commands.LeaveTopic{} = cmd) do
    push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_leave",
        payload: %{},
        ref: state.current_ref_str
      },
      state
    )

    {:noreply, state}
  end

  def handle_command(state, %Commands.CloseConnection{}) do
    @gun.close(state.conn)

    route_event state, %Events.ChannelClosed{
      reason: :client_disconnect_requested
    }

    {:stop, {:shutdown, :disconnected}, state}
  end

  # coveralls-ignore-start
  def handle_command(state, command) do
    Logger.error("""
    #{inspect(__MODULE__)} received a command it is not setup to handle:
    #{inspect(command)}.

    Please open an issue in NFIBrokerage/slipstream with any available details
    leading to this logger message.
    """)

    {:noreply, state}
  end

  # coveralls-ignore-stop

  # ---

  @spec handle_event(%State{}, event :: struct()) ::
          {:noreply, new_state} | {:stop, reason :: term(), new_state}
        when new_state: %State{}
  def handle_event(state, event)

  def handle_event(state, %Events.PingReceived{}) do
    @gun.ws_send(state.conn, :pong)

    {:noreply, state}
  end

  def handle_event(state, %Events.ChannelClosed{} = event) do
    @gun.close(state.conn)

    route_event state, event

    {:stop, :normal, state}
  end

  def handle_event(state, %type{}) when type in @noop_event_types,
    do: {:noreply, state}

  def handle_event(state, event) do
    route_event state, event

    {:noreply, state}
  end

  # ---

  def push_message(message, state) do
    @gun.ws_send(state.conn, {:text, encode(message, state)})
  end

  def push_heartbeat(state) do
    %Message{
      topic: "phoenix",
      event: "heartbeat",
      ref: state.heartbeat_ref,
      payload: %{}
    }
    |> push_message(state)
  end

  defp encode(%Message{} = message, state) do
    [
      message.join_ref,
      message.ref,
      message.topic,
      message.event,
      message.payload
    ]
    |> encode_fn(state).()
  end

  defp encode_fn(state) do
    module = state.config.json_parser

    if function_exported?(module, :encode_to_iodata!, 1) do
      &module.encode_to_iodata!/1
    else
      &module.encode!/1
    end
  end

  def decode(message, state) do
    decode_fn(state).(message)
  end

  defp decode_fn(state) do
    module = state.config.json_parser

    &module.decode/1
  end

  # try decoding as json
  def decode_message({encoding, message}, state)
      when encoding in [:text, :binary] and is_binary(message) do
    case decode_fn(state).(message) do
      {:ok, [join_ref, ref, topic, event, payload | _]} ->
        %Message{
          join_ref: join_ref,
          ref: ref,
          topic: topic,
          event: event,
          payload: payload
        }

      # coveralls-ignore-start
      # this may occur if the remote websocket server does not support the v2
      # transport packets
      {:ok, decoded_json} when is_map(decoded_json) ->
        Message.from_map!(decoded_json)

      {:error, _any} ->
        message

      # coveralls-ignore-stop
    end
  end

  def decode_message(:ping, _state), do: :ping
  def decode_message(:pong, _state), do: :pong

  # coveralls-ignore-start
  def decode_message({:close, timeout, reason}, _state) do
    {:close, timeout, reason}
  end

  # coveralls-ignore-stop

  # this method of getting the path of a URI (including query) is maybe a bit
  # unorthodox, but I think it's better than string manipulation
  @spec path(URI.t()) :: charlist()
  def path(%URI{} = uri) do
    # select the v2 JSON serialization pattern
    query = URI.decode_query(uri.query || "", %{"vsn" => "2.0.0"})

    uri
    |> Map.merge(%{
      authority: nil,
      host: nil,
      port: nil,
      scheme: nil,
      userinfo: nil,
      path: uri.path || "/",
      query: URI.encode_query(query)
    })
    |> URI.to_string()
    |> to_charlist()
  end
end
