defmodule Slipstream.GenServerTest do
  use Slipstream.SocketTest

  setup do
    client = MyApp.GenServerClient

    start_supervised!({client, uri: "ws://localhost", test_mode?: true})

    [client: client]
  end

  test "casting a topic join results in the client asking to join", c do
    accept_connect(c.client)

    topic = "rooms:lobby"
    params = %{"fizz" => "buzz"}

    GenServer.cast(c.client, {:join, topic, params})

    assert_join ^topic, ^params, :ok
  end

  test "calling with a ping request gives a synchronous pong result", c do
    accept_connect(c.client)

    assert GenServer.call(c.client, :ping) == :pong
  end
end
