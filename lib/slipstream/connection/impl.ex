defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State
  alias Phoenix.Socket.Message

  def connect(%State{config: configuration} = state) do
    uri = configuration.uri

    # N.B. I've _never_ seen this match fail
    # if it does, please open an issue
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

    %State{state | conn: conn, stream_ref: stream_ref}
  end

  def route_event(%State{socket_pid: pid}, event) do
    send(pid, {:__slipstream__, event})
  end

  def push_message(message, state) do
    :gun.ws_send(state.conn, {:text, encode(message, state)})
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

      {:ok, decoded_json} when is_map(decoded_json) ->
        Message.from_map!(decoded_json)

      {:error, _any} ->
        message
    end
  end

  def decode_message(:ping, _state), do: :ping
  def decode_message(:pong, _state), do: :pong

  def decode_message({:close, timeout, reason}, _state) do
    {:close, timeout, reason}
  end

  # does a retry with back-off based on the lists of backoff times stored
  # in the connection configuration
  def retry_time(:reconnect, %State{} = state) do
    backoff_times = state.config.reconnect_after_msec
    try_number = state.reconnect_try_number

    retry_time(backoff_times, try_number)
  end

  # def retry_time(:rejoin, %State{} = state) do
    # backoff_times = state.config.rejoin_after_msec
    # try_number = state.rejoin_try_number
#
    # retry_time(backoff_times, try_number)
  # end

  def retry_time(backoff_times, try_number)
      when is_list(backoff_times) and is_integer(try_number) and try_number > 0 do
    # if the index goes beyond the length of the list, we always return
    # the final element in the list
    default = Enum.at(backoff_times, -1)

    Enum.at(backoff_times, try_number, default)
  end

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
