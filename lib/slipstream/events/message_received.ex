defmodule Slipstream.Events.MessageReceived do
  @moduledoc false

  # a message that says that a new message has arrived

  defstruct [:topic, :event, :payload]
end
