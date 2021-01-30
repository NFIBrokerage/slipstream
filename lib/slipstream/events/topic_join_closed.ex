defmodule Slipstream.Events.TopicJoinClosed do
  @moduledoc false

  defstruct [:topic, :reason, :ref]
end
