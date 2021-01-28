defmodule Slipstream.Events.ChannelConnectFailed do
  @moduledoc false

  defstruct []

  def to_reason(%__MODULE__{} = event) do
    # TODO implement
    inspect(event)
  end
end

defimpl Slipstream.Callback, for: Slipstream.Events.ChannelConnectFailed do
  def dispatch(event, socket) do
    {:handle_disconnected, [Slipstream.Events.ChannelConnectFailed.to_reason(event), socket]}
  end
end
