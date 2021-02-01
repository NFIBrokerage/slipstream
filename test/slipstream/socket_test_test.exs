defmodule Slipstream.SocketTestTest do
  # Slipstream.SocketTest is an exunit case template
  use Slipstream.SocketTest

  @moduledoc """
  A test suite that tests that a test suite tests tests

  Note that this is not necessarily a good example to follow for testing
  clients: in order to make assertions about the status of the client, we have
  written a client fixture (`@fixture`) that sends messages to the test process
  when meaningful state changes occur (on connection, e.g.). This is not
  recommended for writing clients in the wild.
  """
  @moduledoc since: "0.2.0"

  @fixture Slipstream.TestModeClient

  setup do
    [topic: "rooms:lobby", event: "msg:new", params: %{"fizz" => "buzz"}]
  end

  describe "given that the fixture is spawned" do
    setup do
      start_supervised!({@fixture, self()})

      :ok
    end

    test "the client connects when we do an accept_connect/1" do
      accept_connect(@fixture)

      assert_receive {@fixture, :connected}
    end

    test "passing a nil client or fake name raises ArgumentError" do
      assert_raise ArgumentError, ~r"cannot find pid for client nil", fn ->
        accept_connect(nil)
      end

      assert_raise ArgumentError, ~r"cannot find pid for client :foo", fn ->
        accept_connect(:foo)
      end
    end

    test "passing a dead client will raise ArgumentError" do
      pid = spawn(fn -> exit(:normal) end)
      ref = Process.monitor(pid)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute Process.alive?(pid)

      assert_raise ArgumentError,
                   ~r"cannot send to client #PID<[\d\.]+> that is not alive",
                   fn ->
                     accept_connect(pid)
                   end
    end

    test "we may connect and join a topic all at once with connect_and_assert_join/5",
         c do
      topic = c.topic
      params = c.params

      join(topic, params)

      connect_and_assert_join @fixture, ^topic, ^params, {:ok, params}

      assert_receive {@fixture, :connected}
      assert_receive {@fixture, :joined, ^topic, ^params}
    end

    test "the error atom returns a join-crashed response", c do
      topic = c.topic
      params = c.params

      join(topic, params)

      connect_and_assert_join @fixture, ^topic, ^params, :error

      assert_receive {@fixture, :connected}

      assert_receive {@fixture, :topic_closed, ^topic,
                      {:failed_to_join, %{"error" => "join crashed"}}}
    end
  end

  describe "given the client is connected" do
    setup do
      start_supervised!({@fixture, self()})

      accept_connect(@fixture)

      assert_receive {@fixture, :connected}

      :ok
    end

    test "disconnect/2 disconnects the client" do
      reason = :bye!

      disconnect(@fixture, reason)

      assert_receive {@fixture, :disconnected, ^reason}
    end

    test "assert_join/4 allows a topic join", c do
      topic = c.topic
      params = c.params

      join(topic, params)

      assert_join ^topic, ^params, :ok

      assert_receive {@fixture, :joined, ^topic, %{}}

      # once joined, we do not duplicate the join
      refute_join ^topic, ^params
    end

    test "we may assert that a client attempts to disconnect" do
      GenServer.cast(@fixture, :disconnect)
      assert_disconnect()
      # no duplicate disconnect request
      refute_disconnect()
    end
  end

  describe "given the client is connected and joined to a topic" do
    setup c do
      topic = c.topic
      params = c.params

      start_supervised!({@fixture, self()})

      join(topic, params)

      connect_and_assert_join @fixture, ^topic, ^params, :ok

      assert_receive {@fixture, :connected}
      assert_receive {@fixture, :joined, ^topic, %{}}

      [topic: topic, event: "msg:new"]
    end

    test "push/4 triggers c:Slipstream.handle_message/4", c do
      topic = c.topic
      event = c.event
      params = %{"foo" => "bar"}

      push(@fixture, topic, event, params)

      assert_receive {@fixture, :received_message, ^topic, ^event, ^params}
    end

    test "we may assert_push/5 a push from the client and reply/2", c do
      topic = c.topic
      event = c.event
      params = %{"foo" => "bar"}

      GenServer.cast(@fixture, {:push, topic, event, params})
      assert_push ^topic, ^event, ^params

      GenServer.cast(@fixture, {:push, topic, event, params})
      assert_push ^topic, ^event, ^params, my_ref_binding

      reply(@fixture, my_ref_binding, params)

      assert_receive {@fixture, :received_reply, ^my_ref_binding, ^params}

      # we won't send any more messages
      refute_push ^topic, ^event, ^params
    end

    test "we may capture when the client attepts to leave", c do
      topic = c.topic
      GenServer.cast(@fixture, {:leave, topic})
      # N.B. bindings made with these macros can be used after the assert_ macro
      assert_leave left_topic
      assert left_topic == topic

      assert_receive {@fixture, :left, ^topic}

      # we do not duplicate the request to leave
      refute_leave ^topic
    end
  end

  defp join(topic, params) do
    @fixture
    |> Slipstream.SocketTest.__check_client__()
    |> send({:join, topic, params})
  end
end
