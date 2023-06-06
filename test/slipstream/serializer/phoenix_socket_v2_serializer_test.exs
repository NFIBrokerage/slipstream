defmodule Slipstream.Serializer.PhoenixSocketV2SerializerTest do
  use ExUnit.Case

  @moduledoc """
  Tests cover the exception handlings of PhoenixSocketV2Serializer.
  """

  import Slipstream.Serializer.PhoenixSocketV2Serializer,
    only: [encode!: 2, decode!: 2]

  alias Slipstream.Message

  describe "encode!/2 raise Slipstream.Serializer.EncodeError" do
    test "when binary payload, topic size is greater than 255 bytes" do
      assert_raise(Slipstream.Serializer.EncodeError, fn ->
        encode!(
          %Message{
            payload: {:binary, _data = ""},
            topic: String.duplicate("a", 256)
          },
          json_parser: Jason
        )
      end)
    end

    test "when payload won't be encoded" do
      assert_raise(Slipstream.Serializer.EncodeError, fn ->
        # tuple cannot be encoded to JSON
        encode!(%Message{payload: {"a"}}, json_parser: Jason)
      end)
    end
  end

  describe "decode!/1 raise Slipstream.Serializer.DecodeError" do
    test "binary does't match function arugment pattern" do
      assert_raise(Slipstream.Serializer.DecodeError, fn ->
        decode!(<<>>, opcode: :binary, json_parser: Jason)
      end)
    end
  end
end
