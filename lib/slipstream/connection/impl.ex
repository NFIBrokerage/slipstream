# we should use Application.compile_env/3 because it's available to us, but
# this is a library which may be used by projects with elixir versions <= 1.9.0
# and we really only use the application-config-to-module-attribute thing for
# testing. In addition, we really _want_ this to be a compile-time config.
# credo:disable-for-this-file Credo.Check.Warning.ApplicationConfigInModuleAttribute
defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State
  alias Phoenix.Socket.Message
  import Slipstream.Signatures, only: [event: 1]

  # in test mode, we want to be able to swap out `:gun` for a mock
  # in dev/prod mode, we want to compile in `:gun` as the gun-client
  if Mix.env() == :test do
    def gun, do: Application.get_env(:slipstream, :gun_client, :gun)
  else
    @gun Application.get_env(:slipstream, :gun_client, :gun)
    def gun, do: @gun
  end

  @spec connect(%State{}) :: %State{}
  def connect(%State{config: configuration} = state) do
    uri = configuration.uri

    # N.B. I've _never_ seen this match fail
    # if it does, please open an issue
    {:ok, conn} =
      gun().open(
        to_charlist(uri.host),
        uri.port,
        configuration.gun_open_options
      )

    stream_ref =
      gun().ws_upgrade(
        conn,
        path(uri),
        configuration.headers,
        _opts = %{}
      )

    %State{state | conn: conn, stream_ref: stream_ref}
  end

  @spec route_event(%State{}, event :: struct()) :: term()
  def route_event(%State{client_pid: pid}, event) do
    send(pid, event(event))
  end

  # ---

  def push_message(message, state) do
    gun().ws_send(state.conn, {:text, encode(message, state)})
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
      # coveralls-ignore-start
      &module.encode!/1

      # coveralls-ignore-stop
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
  def decode_message({:close, _, _} = message, _state), do: message

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
