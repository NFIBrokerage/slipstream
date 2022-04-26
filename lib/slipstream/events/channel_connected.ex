defmodule Slipstream.Events.ChannelConnected do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:pid, :config, :response_headers]
end
