# we should use Application.compile_env/3 because it's available to us, but
# this is a library which may be used by projects with elixir versions <= 1.9.0
# and we really only use the application-config-to-module-attribute thing for
# testing. In addition, we really _want_ this to be a compile-time config.
# credo:disable-for-this-file Credo.Check.Warning.ApplicationConfigInModuleAttribute
defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State
  alias Slipstream.Message
  alias Slipstream.Serializer

  import Slipstream.Signatures, only: [event: 1]

  @spec route_event(State.t(), event :: struct()) :: term()
  def route_event(%State{client_pid: pid}, event) do
    send(pid, event(event))
  end

  def http_connect(config) do
    Mint.HTTP.connect(
      map_http_scheme(config.uri.scheme),
      config.uri.host,
      config.uri.port,
      config.mint_opts
    )
  end

  # coveralls-ignore-start
  defp map_http_scheme("wss"), do: :https
  # coveralls-ignore-stop
  defp map_http_scheme(_), do: :http

  # coveralls-ignore-start
  defp map_ws_scheme("wss"), do: :wss
  # coveralls-ignore-stop
  defp map_ws_scheme(_), do: :ws

  def websocket_upgrade(conn, config) do
    Mint.WebSocket.upgrade(
      map_ws_scheme(config.uri.scheme),
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
           Mint.WebSocket.stream_request_body(
             state.conn,
             state.request_ref,
             data
           ) do
      {:ok, %State{state | conn: conn, websocket: websocket}}
    else
      # coveralls-ignore-start
      {:error, %Mint.WebSocket{} = websocket, reason} ->
        {:error, put_in(state.websocket, websocket), reason}

      {:error, conn, reason} ->
        {:error, put_in(state.conn, conn), reason}
        # coveralls-ignore-stop
    end
  end

  def push_message(%Message{payload: {:binary, _}} = message, state) do
    push_message({:binary, encode(message, state)}, state)
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
    module = state.config.serializer
    module.encode!(message, json_parser: state.config.json_parser)
  end

  def decode_message({encoding, message}, state)
      when encoding in [:text, :binary] and is_binary(message) do
    module = state.config.serializer

    try do
      module.decode!(message,
        opcode: encoding,
        json_parser: state.config.json_parser
      )
    rescue
      # coveralls-ignore-start
      _ in [Serializer.DecodeError] ->
        message
        # coveralls-ignore-stop
    end
  end

  # coveralls-ignore-start
  def decode_message(:ping, _state), do: :ping
  def decode_message(:pong, _state), do: :pong
  def decode_message({:close, _, _} = message, _state), do: message
  # coveralls-ignore-stop

  # this method of getting the path of a URI (including query) is maybe a bit
  # unorthodox, but I think it's better than string manipulation
  @spec path(URI.t()) :: String.t()
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
