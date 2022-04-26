defmodule Slipstream.Events.TopicJoinSucceeded do
  @moduledoc false

  @type t :: %__MODULE__{}

  # a message that says that a topic has been successfully joined

  defstruct [:topic, :response, :ref]
end
