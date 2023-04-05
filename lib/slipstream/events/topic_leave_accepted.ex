defmodule Slipstream.Events.TopicLeaveAccepted do
  @moduledoc false

  @type t :: %__MODULE__{}

  # this is the direct reply to our request to LeaveTopic, and precedes a
  # soon-to-arrive TopicLeft event
  # the difference is that this event is triggered by a phx_reply message
  # while the TopicLeft is triggered by phx_close

  defstruct [:topic]
end
