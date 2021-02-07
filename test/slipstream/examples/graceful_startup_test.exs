defmodule Slipstream.GracefulStartupTest do
  use Slipstream.SocketTest

  @client MyApp.GracefulStartupClient

  describe "given the configuration is not in application-config" do
    setup do
      :ok
    end

    test "the server does not start up" do
      assert start_supervised(@client) == {:ok, :undefined}
    end
  end

  describe "given the configuration is in application-config but is not valid" do
    setup do
      # n.b.: http is not a valid scheme for websockets
      config = [uri: "http://localhost:4000/socket/websocket"]
      Application.put_env(:slipstream, @client, config)

      on_exit(fn ->
        Application.delete_env(:slipstream, @client)
      end)

      :ok
    end

    test "the client fails to start up" do
      assert {:error,
              {{%NimbleOptions.ValidationError{}, _stack_trace}, _child_spec}} =
               start_supervised(@client)
    end
  end

  describe "given the configuration is in application-config and is valid" do
    setup do
      # n.b.: http is not a valid scheme for websockets
      config = [uri: "ws://localhost:4000/socket/websocket", test_mode?: true]
      Application.put_env(:slipstream, @client, config)

      on_exit(fn ->
        Application.delete_env(:slipstream, @client)
      end)

      :ok
    end

    test "the client starts up" do
      assert {:ok, pid} = start_supervised(@client)
      accept_connect(@client)
      assert Process.alive?(pid)
    end
  end
end
