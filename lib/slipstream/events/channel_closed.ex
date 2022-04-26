defmodule Slipstream.Events.ChannelClosed do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:reason]
end
