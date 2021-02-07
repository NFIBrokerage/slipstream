defmodule Slipstream.RepeaterTest do
  use Slipstream.SocketTest

  @client MyApp.RepeaterClient
  @endpoint SlipstreamWeb.Endpoint
  @topic "rooms:lobby"

  describe "given the client has connected to the endpoint and joined a topic" do
    setup do
      start_supervised!({@client, uri: "ws://localhost:4000/socket/websocket", test_mode?: true})

      connect_and_assert_join @client, @topic, %{}, :ok

      :ok
    end

    test "when a message is pushed to the client, it re-publishes it" do
      @endpoint.subscribe(@topic)
      event = "some_broadcasted_event"
      params = %{"fizz" => "buzz"}

      push(@client, @topic, event, params)

      assert_receive %Phoenix.Socket.Broadcast{topic: @topic, event: ^event, payload: ^params}
    end
  end
end
