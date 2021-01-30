defmodule Slipstream.Events.ChannelConnectFailed do
  @moduledoc false

  defstruct ~w[request_id status_code resp_headers response]a

  def to_reason(%__MODULE__{} = event) do
    Map.from_struct(event)
  end
end
