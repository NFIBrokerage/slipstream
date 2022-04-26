defmodule Slipstream.Events.PongReceived do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:data]
end
