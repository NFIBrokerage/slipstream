defmodule Slipstream.Serializer do
  @moduledoc """
  A behaviour that serializes incoming and outgoing socket messages.
  """

  @doc """
  Encodes `Slipstream.Message` structs to binary.

  Should return either a binary (string) when using a text based protocol
  or `{:binary, binary}` for cases where a binary protocol is used over
  the wire (such as MessagePack).
  """
  @callback encode!(Slipstream.Message.t(), options :: Keyword.t()) ::
              binary() | {:binary, binary()}

  @doc """
  Decodes binary into `Slipstream.Message` struct.
  """
  @callback decode!(binary, options :: Keyword.t()) :: Slipstream.Message.t()
end
