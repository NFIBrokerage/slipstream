defmodule Slipstream.ConfigurationTest do
  use ExUnit.Case, async: true

  alias Slipstream.Configuration, as: Config

  test "empty config fails validation" do
    assert {:error, %NimbleOptions.ValidationError{}} = Config.validate([])
    assert_raise NimbleOptions.ValidationError, fn -> Config.validate!([]) end
  end

  describe "given a valid URI" do
    setup do
      [uri: "ws://localhost/socket/websocket?foo=bar"]
    end

    test "config with just URI passes, and ws protocol defaults to port 80",
         c do
      assert {:ok, %Config{} = config} = Config.validate(uri: c.uri)
      assert %Config{} = ^config = Config.validate!(uri: c.uri)

      assert match?(%URI{port: 80, scheme: "ws"}, config.uri)
    end

    test "WSS is assumed to be port 443", c do
      uri = String.replace(c.uri, ~r/^ws/, "wss")
      assert {:ok, %Config{} = config} = Config.validate(uri: uri)

      assert match?(%URI{port: 443, scheme: "wss"}, config.uri)
    end

    test "HTTP fails validation", c do
      uri = String.replace(c.uri, ~r/^ws/, "http")

      assert {:error, reason} = Config.validate(uri: uri)

      assert %NimbleOptions.ValidationError{key: :uri, message: message} =
               reason

      assert message =~ ~s(unknown scheme "http")
    end
  end
end
