defmodule Slipstream.Events.TopicLeft do
  @moduledoc false

  @derive {Slipstream.Callback, callback: :handle_left, args: [:topic]}

  # a topic has been left by the connection

  defstruct [:topic, :ref]
end
