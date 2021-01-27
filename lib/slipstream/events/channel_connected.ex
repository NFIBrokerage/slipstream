defmodule Slipstream.Events.ChannelConnected do
  @moduledoc false

  defstruct [:pid, :config, :response_headers]
end
