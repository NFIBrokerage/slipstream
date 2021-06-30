# we should use Application.compile_env/3 because it's available to us, but
# this is a library which may be used by projects with elixir versions <= 1.9.0
# and we really only use the application-config-to-module-attribute thing for
# testing. In addition, we really _want_ this to be a compile-time config.
# credo:disable-for-this-file Credo.Check.Warning.ApplicationConfigInModuleAttribute
defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State
  alias Slipstream.Message
  import Slipstream.Signatures, only: [event: 1]

  @spec route_event(%State{}, event :: struct()) :: term()
  def route_event(%State{client_pid: pid}, event) do
    send(pid, event(event))
  end

  def http_connect(config) do
    Mint.HTTP.connect(
      map_scheme(config.uri.scheme),
      config.uri.host,
      config.uri.port,
      config.mint_opts
    )
  end

  defp map_scheme("wss"), do: :https
  defp map_scheme(_), do: :http

  def websocket_upgrade(conn, config) do
    Mint.WebSocket.upgrade(
      conn,
      path(config.uri),
      config.headers,
      extensions: config.extensions
    )
  end

  # ---

  def push_message(frame, state) when is_tuple(frame) do
    with {:ok, websocket, data} <-
           Mint.WebSocket.encode(state.websocket, frame),
         {:ok, conn} <-
           Mint.HTTP.stream_request_body(state.conn, state.request_ref, data) do
      {:ok, %State{state | conn: conn, websocket: websocket}}
    end
  end

  def push_message(message, state) do
    push_message({:text, encode(message, state)}, state)
  end

  # coveralls-ignore-start
  def push_heartbeat(state) do
    %Message{
      topic: "phoenix",
      event: "heartbeat",
      ref: state.heartbeat_ref,
      payload: %{}
    }
    |> push_message(state)
  end

  # coveralls-ignore-stop

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

    &module.encode!/1
  end

  # coveralls-ignore-start
  def decode(message, state) do
    decode_fn(state).(message)
  end

  # coveralls-ignore-stop

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
  def decode_message({:close, _, _} = message, _state), do: message
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
  end
end
