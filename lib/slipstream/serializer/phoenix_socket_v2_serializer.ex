defmodule Slipstream.Serializer.PhoenixSocketV2Serializer do
  @behaviour Slipstream.Serializer

  alias Slipstream.Message
  alias Slipstream.Serializer

  @push 0
  @reply 1

  def encode!(binary, opts \\ [])

  def encode!(%Message{payload: {:binary, data}} = message, _opts) do
    try do
      join_ref = to_string(message.join_ref)
      ref = to_string(message.ref)
      join_ref_size = byte_size!(join_ref, :join_ref, 255)
      ref_size = byte_size!(ref, :ref, 255)
      topic_size = byte_size!(message.topic, :topic, 255)
      event_size = byte_size!(message.event, :event, 255)

      <<
        @push::size(8),
        join_ref_size::size(8),
        ref_size::size(8),
        topic_size::size(8),
        event_size::size(8),
        join_ref::binary-size(join_ref_size),
        ref::binary-size(ref_size),
        message.topic::binary-size(topic_size),
        message.event::binary-size(event_size),
        data::binary
      >>
    rescue
      exception in [ArgumentError] ->
        reraise(
          Serializer.EncodeError,
          [message: exception.message],
          __STACKTRACE__
        )
    end
  end

  def encode!(%Message{} = message, opts) do
    try do
      [
        message.join_ref,
        message.ref,
        message.topic,
        message.event,
        message.payload
      ]
      |> Jason.encode!(opts)
    rescue
      exception in [Jason.EncodeError] ->
        reraise(
          Serializer.EncodeError,
          [message: exception.message],
          __STACKTRACE__
        )
    end
  end

  def decode!(binary, opts \\ [])

  def decode!(
        <<
          @push::size(8),
          join_ref_size::size(8),
          topic_size::size(8),
          event_size::size(8),
          join_ref::binary-size(join_ref_size),
          topic::binary-size(topic_size),
          event::binary-size(event_size),
          data::binary
        >>,
        _opts
      ) do
    %Message{
      topic: topic,
      event: event,
      payload: {:binary, data},
      ref: nil,
      join_ref: join_ref
    }
  end

  def decode!(
        <<
          @reply::size(8),
          join_ref_size::size(8),
          ref_size::size(8),
          topic_size::size(8),
          status_size::size(8),
          join_ref::binary-size(join_ref_size),
          ref::binary-size(ref_size),
          topic::binary-size(topic_size),
          status::binary-size(status_size),
          data::binary
        >>,
        _opts
      ) do
    %Message{
      topic: topic,
      event: "phx_reply",
      payload: %{"response" => {:binary, data}, "status" => status},
      ref: ref,
      join_ref: join_ref
    }
  end

  def decode!(binary, opts) do
    try do
      case Jason.decode!(binary, opts) do
        [join_ref, ref, topic, event, payload | _] ->
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
        decoded_json when is_map(decoded_json) ->
          Message.from_map!(decoded_json)
          # coveralls-ignore-stop
      end
    rescue
      exception in [Jason.DecodeError, KeyError] ->
        reraise(
          Serializer.DecodeError,
          [message: exception.message],
          __STACKTRACE__
        )
    end
  end

  defp byte_size!(bin, kind, max) do
    case byte_size(bin) do
      size when size <= max ->
        size

      oversized ->
        raise ArgumentError, """
        unable to convert #{kind} to binary.

            #{inspect(bin)}

        must be less than or equal to #{max} bytes, but is #{oversized} bytes.
        """
    end
  end
end
