defmodule Slipstream.Events.TopicJoinClosed do
  @moduledoc false

  # @derive {Slipstream.Callback, callback: :handle_left, args: [:topic, :reason]}

  defstruct [:topic, :reason, :ref]
end
