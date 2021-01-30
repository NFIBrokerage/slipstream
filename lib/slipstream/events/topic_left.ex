defmodule Slipstream.Events.TopicLeft do
  @moduledoc false

  # a topic has been left by the connection

  defstruct [:topic, :ref]
end
