defmodule Slipstream.MessageTest do
  use ExUnit.Case, async: true

  alias Slipstream.Message

  test "from_map!/1 raises a KeyError on a malformed message" do
    # malformed because there is no payload key
    malformed_message = %{
      topic: "rooms:lobby",
      event: "msg:new",
      ref: nil,
      join_ref: nil
    }

    assert_raise KeyError, fn -> Message.from_map!(malformed_message) end
  end
end
