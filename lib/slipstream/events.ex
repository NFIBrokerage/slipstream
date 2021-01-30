defmodule Slipstream.Events do
  @moduledoc false

  require Logger

  alias Phoenix.Socket.Message

  alias __MODULE__.{
    MessageReceived,
    ReplyReceived,
    HeartbeatAcknowledged,
    TopicJoinSucceeded,
    TopicJoinFailed,
    TopicJoinClosed,
    TopicLeft,
    TopicLeaveAccepted,
    PingReceived,
    PongReceived
  }

  alias Slipstream.Connection.State

  def map(server_message, connection_state)

  # coveralls-ignore-start
  def map(:ping, _state), do: %PingReceived{}
  def map(:pong, _state), do: %PongReceived{}

  # coveralls-ignore-stop

  def map(
        %Message{
          topic: topic,
          event: event,
          payload: payload,
          ref: ref
        },
        _state
      )
      when ref == nil do
    %MessageReceived{topic: topic, event: event, payload: payload}
  end

  def map(
        %Message{
          topic: "phoenix",
          event: "phx_reply",
          payload: %{"response" => response, "status" => "ok"},
          ref: ref
        },
        _state
      )
      when map_size(response) == 0 do
    %HeartbeatAcknowledged{ref: ref}
  end

  # a reply in which join_ref == ref is a reply to a request to join a topic
  def map(
        %Message{
          topic: topic,
          event: "phx_reply",
          payload: %{"response" => response, "status" => status},
          ref: ref,
          join_ref: join_ref
        },
        _state
      )
      when ref != nil and ref == join_ref do
    type = if status == "ok", do: TopicJoinSucceeded, else: TopicJoinFailed

    struct(type, topic: topic, ref: ref, response: response)
  end

  def map(
        %Message{
          topic: topic,
          event: "phx_reply",
          payload: %{"response" => response, "status" => status},
          ref: ref
        },
        state
      )
      when ref != nil do
    if State.leave_ref?(state, ref) do
      %TopicLeaveAccepted{topic: topic}
    else
      %ReplyReceived{
        topic: topic,
        status: String.to_atom(status),
        response: response,
        ref: ref
      }
    end
  end

  def map(
        %Message{
          topic: topic,
          event: "phx_error",
          payload: payload,
          ref: ref
        },
        state
      ) do
    true = State.join_ref?(state, ref)

    %TopicJoinClosed{topic: topic, reason: {:error, payload}, ref: ref}
  end

  def map(
        %Message{
          topic: topic,
          event: "phx_close",
          payload: payload,
          ref: _ref
        },
        _state
      )
      when map_size(payload) == 0 do
    %TopicLeft{topic: topic}
  end

  def map(message, _state) do
    # coveralls-ignore-start
    Logger.debug(
      "#{inspect(__MODULE__)} received unknown message #{inspect(message)}"
    )

    # coveralls-ignore-stop

    nil
  end
end
