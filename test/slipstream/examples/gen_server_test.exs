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

  test "the synchronous join API works in the happy-path", c do
    accept_connect(c.client)

    import Task, only: [async: 1, await: 1]

    topic = "rooms:lobby"
    params = %{"fizz" => "buzz"}

    call = async(fn -> GenServer.call(c.client, {:join, topic, params}) end)

    assert_join ^topic, ^params, {:ok, %{"foo" => "bar"}}

    assert await(call) == {:ok, %{"foo" => "bar"}}
  end

  test "the :conclude_subscription message shuts down and disconnects the client",
       c do
    accept_connect(c.client)
    client_ref = c.client |> GenServer.whereis() |> Process.monitor()

    c.client |> GenServer.whereis() |> send(:conclude_subscription)

    assert_disconnect()

    assert_receive {:DOWN, ^client_ref, :process, _pid, :normal}
  end
end
