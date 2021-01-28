defmodule Slipstream.Events.ChannelConnectFailed do
  @moduledoc false

  defstruct []

  def to_reason(%__MODULE__{} = event) do
    # TODO implement
    inspect(event)
  end
end
