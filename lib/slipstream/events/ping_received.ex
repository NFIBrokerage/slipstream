defmodule Slipstream.Events.PingReceived do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:data]
end
