defmodule Slipstream.TokenRefreshTest do
  use Slipstream.SocketTest

  setup do
    client = MyApp.TokenRefreshClient

    start_supervised!({client, uri: "ws://localhost", test_mode?: true})

    [client: client]
  end

  describe "given the client is joined to multiple topics" do
    setup c do
      accept_connect(c.client)
      :ok
    end

    test "when the channel is disconnected, it reconnects and rejoins each topic",
         c do
      disconnect(c.client, {:error, {nil, %{status_code: 403}}})
      %{assigns: %{config: config}} = :sys.get_state(c.client)

      assert config
             |> Keyword.get(:uri)
             |> String.contains?("token=get_new_token_here")

      accept_connect(c.client)
    end
  end
end
