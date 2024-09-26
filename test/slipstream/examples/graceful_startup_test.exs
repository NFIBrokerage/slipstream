defmodule Slipstream.GracefulStartupTest do
  use Slipstream.SocketTest

  @client MyApp.GracefulStartupClient

  import ExUnit.CaptureLog

  describe "given the configuration is not in application-config" do
    setup do
      :ok
    end

    test "the client does not start up" do
      log =
        capture_log([level: :warning], fn ->
          assert start_supervised(@client) == {:ok, :undefined}
        end)

      assert log =~ "Could not start"
      assert log =~ inspect(@client)
      assert log =~ "because it is not configured"
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

    test "the client does not start up" do
      log =
        capture_log([level: :error], fn ->
          assert start_supervised(@client) == {:ok, :undefined}
        end)

      assert log =~ "Could not start"
      assert log =~ inspect(@client)
      assert log =~ "because the configuration is invalid"
      assert log =~ "%NimbleOptions.ValidationError{"
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
