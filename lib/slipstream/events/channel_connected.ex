defmodule Slipstream.Events.ChannelConnected do
  @moduledoc false

  # @derive {Slipstream.Callback, callback: :handle_connected, args: []}

  defstruct [:pid, :config, :response_headers]
end
