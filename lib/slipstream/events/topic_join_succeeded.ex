defmodule Slipstream.Events.TopicJoinSucceeded do
  @moduledoc false

  # a message that says that a topic has been successfully joined

  defstruct [:topic, :response, :ref]
end
