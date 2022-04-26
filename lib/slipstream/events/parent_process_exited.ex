defmodule Slipstream.Events.ParentProcessExited do
  @moduledoc false

  @type t :: %__MODULE__{}

  defstruct [:reason]
end
