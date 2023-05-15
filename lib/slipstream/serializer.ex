defmodule Slipstream.Serializer do
  @moduledoc """
  A behaviour that serializes incoming and outgoing socket messages.
  """

  @doc """
  Encodes `Slipstream.Message` structs to binary.
  """
  @callback encode!(Slipstream.Message.t(), options :: Keyword.t()) :: binary()

  @doc """
  Decodes binary into `Slipstream.Message` struct.
  """
  @callback decode!(binary, options :: Keyword.t()) :: Slipstream.Message.t()
end
