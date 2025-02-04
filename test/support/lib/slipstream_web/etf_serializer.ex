defmodule SlipstreamWeb.EtfSerializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{} = msg) do
    data = :erlang.term_to_binary([nil, nil, msg.topic, msg.event, msg.payload])
    {:socket_push, :binary, data}
  end

  @impl true
  def encode!(%Reply{} = reply) do
    data = [
      reply.join_ref,
      reply.ref,
      reply.topic,
      "phx_reply",
      %{status: reply.status, response: reply.payload}
    ]

    {:socket_push, :binary, :erlang.term_to_binary(data)}
  end

  def encode!(%Message{} = msg) do
    data = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload]
    {:socket_push, :binary, :erlang.term_to_binary(data)}
  end

  @impl true
  def decode!(raw_message, _opts) do
    [join_ref, ref, topic, event, payload | _] =
      :erlang.binary_to_term(raw_message)

    %Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref
    }
  end
end
