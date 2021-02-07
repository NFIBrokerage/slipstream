defmodule Slipstream.RejoinOnReconnectTest do
  use Slipstream.SocketTest

  setup do
    client = MyApp.RejoinOnReconnectClient

    start_supervised!({client, uri: "ws://localhost", test_mode?: true})

    [client: client, topics: ~w[foo bar baz]]
  end

  describe "given the client is joined to multiple topics" do
    setup c do
      accept_connect(c.client)

      Enum.each(c.topics, &c.client.join/1)

      assert_join "foo", %{}, :ok
      assert_join "bar", %{}, :ok
      assert_join "baz", %{}, :ok

      :ok
    end

    test "when the channel is disconnected, it reconnects and rejoins each topic",
         c do
      disconnect(c.client, :closed_by_remote)

      accept_connect(c.client)

      assert_join "foo", %{}, :ok, 500
      assert_join "bar", %{}, :ok
      assert_join "baz", %{}, :ok
    end
  end
end
