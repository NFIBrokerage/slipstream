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

  # this can either be used to
  # 1. wrap events in a marker that clearly states that it's a slipstream
  #    event
  # 2. match on an event in a receive/2 or function definition expression,
  #    ensuring that the pattern is indeed a slipstream event
  defmacro event(event_pattern) do
    quote do
      {:__slipstream_event__, unquote(event_pattern)}
    end
  end

  def map(server_message, connection_state)

  def map(:ping, _state), do: %PingReceived{}
  def map(:pong, _state), do: %PongReceived{}

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
      ) do
    if map_size(payload) > 0 do
      IO.inspect(payload, label: "phx_close payload Events.map/1")
    end

    %TopicLeft{topic: topic}
  end

  def map(message, _state) do
    Logger.debug(
      "#{inspect(__MODULE__)} received unknown message #{inspect(message)}"
    )

    nil
  end
end
