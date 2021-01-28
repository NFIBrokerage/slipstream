defmodule Slipstream.Events.TopicJoinSucceeded do
  @moduledoc false

  @derive {Slipstream.Callback, callback: :handle_joined, args: [:topic, :response]}

  # a message that says that a topic has been successfully joined

  defstruct [:topic, :response, :ref]
end
