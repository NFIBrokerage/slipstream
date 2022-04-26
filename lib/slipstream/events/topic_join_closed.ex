defmodule Slipstream.Events.TopicJoinClosed do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:topic, :reason, :ref]
end
