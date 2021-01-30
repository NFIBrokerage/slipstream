defmodule Slipstream.Events.ChannelClosed do
  @moduledoc false

  # @derive {Slipstream.Callback, callback: :handle_disconnected, args: [:reason]}

  defstruct [:reason]
end
