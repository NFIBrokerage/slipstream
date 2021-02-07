defmodule SlipstreamTest do
  use ExUnit.Case

  import Slipstream
  import Slipstream.Socket

  test "updating a key in socket assigns which does not exist raises a KeyError" do
    socket = new_socket() |> assign(:foo, [])

    assert_raise KeyError, fn ->
      update(socket, :bar, &Map.merge(&1, %{"fizz" => "buzz"}))
    end
  end
end
