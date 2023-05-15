defmodule Slipstream.Serializer.EncodeError do
  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}
end

defmodule Slipstream.Serializer.DecodeError do
  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}
end
