defmodule Slipstream.Events.NoOp do
  @moduledoc false

  @type t :: %__MODULE__{}

  # declares that something has happened which the server may completely ignore
  defstruct []
end
