defmodule Slipstream.Events.TopicJoinFailed do
  @moduledoc false

  # a message that says that a topic has failed to be joined

  defstruct [:topic, :response, :ref]

  def to_reason(%__MODULE__{} = event) do
    {:failed_to_join, event.response}
  end
end
