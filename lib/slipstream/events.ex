defmodule Slipstream.Events do
  @moduledoc false

  require Logger

  alias Phoenix.Socket.Message

  alias __MODULE__.{
    MessageReceived,
    ReplyReceived,
    HeartbeatAcknowledged,
    CloseRequestedByRemote,
    TopicJoinSucceeded,
    TopicJoinFailed,
    TopicJoinClosed,
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
  def map({:close, _, _}, _state), do: %CloseRequestedByRemote{}

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
          topic: topic,
          event: "phx_reply",
          payload: %{"response" => response, "status" => status},
          ref: ref
        },
        state
      )
      when ref != nil do
    with true <- State.join_ref?(state, ref),
         "ok" <- status do
      %TopicJoinSucceeded{topic: topic, ref: ref, response: response}
    else
      "error" ->
        %TopicJoinFailed{topic: topic, ref: ref, response: response}

      false ->
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
          topic: "phoenix",
          event: "phx_reply",
          payload: %{"response" => %{}, "status" => "ok"},
          ref: ref
        },
        _state
      ) do
    %HeartbeatAcknowledged{ref: ref}
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
          ref: ref
        },
        state
      ) do
    true = State.join_ref?(state, ref)

    %TopicJoinClosed{topic: topic, reason: {:closed, payload}, ref: ref}
  end

  def map(message, _state) do
    Logger.debug(
      "#{inspect(__MODULE__)} received unknown message #{inspect(message)}"
    )

    nil
  end
end
