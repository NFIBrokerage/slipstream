defmodule Slipstream.GenServerOperations do
  use ExUnit.Case, async: true

  @client Slipstream.GenServerLike

  setup_all do
    start_supervised!(@client)

    :ok
  end

  test "sending messages with Kernel.send/2 works" do
    assert {:info, _pid} = send(@client, {:info, self()})

    assert_receive :info_received
  end

  test "sending messages with GenServer.cast/2 works" do
    :ok = GenServer.cast(@client, {:cast, self()})

    assert_receive :cast_received
  end

  test "a typical RPC-like synchronous GenServer call appears blocking" do
    assert GenServer.call(@client, :sync_call) == {:ok, :sync_call}
  end

  test "the async-workflow GenServer.reply also appears blocking" do
    assert GenServer.call(@client, :async_call) == {:ok, :async_call}
  end
end
