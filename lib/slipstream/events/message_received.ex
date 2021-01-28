defmodule Slipstream.Events.MessageReceived do
  @moduledoc false

  @derive {Slipstream.Callback, callback: :handle_message, args: [:topic, :event, :payload]}

  # a message that says that a new message has arrived

  defstruct [:topic, :event, :payload]
end
