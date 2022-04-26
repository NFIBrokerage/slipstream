defmodule Slipstream.Events.TopicLeft do
  @moduledoc false

  @type t :: %__MODULE__{}

  # a topic has been left by the connection

  defstruct [:topic, :ref]
end
