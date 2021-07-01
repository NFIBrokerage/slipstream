defmodule Slipstream.IntegrationTest do
  use ExUnit.Case, async: true

  import Slipstream.PidHelpers

  # tests a slipstream example fixture against the phoenix client running in
  # test mode

  @moduletag :capture_log

  @timeout 500

  @client Slipstream.GoodExample
  @server SlipstreamWeb.TestChannel

  describe "given c:Phoenix.Socket.connect/3 returns :error" do
    setup do
      [config: [uri: "ws://localhost:4001/socket/websocket?reject=yes"]]
    end

    test "the socket is disconnected with :connect_failure reason", c do
      import Slipstream

      assert {:error, {:upgrade_failure, %{status_code: 403}}} =
               c.config
               |> connect!()
               |> await_connect(15_000)
    end
  end

  describe "given a connection has been established through the #{@client}" do
    setup do
      pid = start_supervised!({@client, self()})
      assert_receive {@client, :connected}, @timeout

      [pid: pid, good_topic: "test:good", bad_topic: "test:bad"]
    end

    test "joining a good channel works", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout
    end

    test "duplicate joins do not result in an actual duplicate join", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = join(c.pid, topic)
      refute_receive {@client, :joined, ^topic, _reply}, @timeout
    end

    test "once a channel is joined it can be left", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      assert_receive {@client, :left, ^topic}, @timeout
    end

    test "once a channel is left, you cannot duplicate the leave", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      assert_receive {@client, :left, ^topic}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      refute_receive {@client, :left, ^topic}, @timeout
    end

    test "a message may be pushed to the remote", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "quicksand", %{}})
      assert_receive {@server, :in, ^topic, "quicksand", %{}}, @timeout
    end

    test "if a topic is not yet joined, you may not push a message", c do
      topic = c.good_topic

      :ok = GenServer.cast(c.pid, {:push, topic, "quicksand", %{}})
      refute_receive {@server, :in, ^topic, "quicksand", %{}}, @timeout
    end

    test "a message may be received from the server", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "push to me", %{}})

      assert_receive {@client, :received_message, ^topic, "foo",
                      %{"bar" => "baz"}},
                     @timeout
    end

    test "a reply may be received from the server", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "ping", %{}})

      assert_receive {@client, :received_reply, _ref,
                      {:ok, %{"pong" => "pong"}}},
                     @timeout
    end

    test "a connection may be disconnected", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, :disconnect)
      assert_receive {@client, :disconnected, reason}, @timeout
      assert reason == :client_disconnect_requested
    end

    test "if the remote server raises, we handle a topic disconnect event", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "raise", %{}})
      assert_receive {@client, :topic_closed, ^topic, {:error, %{}}}, @timeout
    end

    test "if the remote server stops, we handle a left event", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "stop", %{}})
      assert_receive {@client, :left, ^topic}, @timeout
    end

    test "trying to join a non-existant topic fails", c do
      topic = "test:no function clause matching"

      :ok = join(c.pid, topic)

      assert_receive {@client, :topic_closed, ^topic,
                      {:failed_to_join, %{"reason" => "join crashed"}}},
                     @timeout
    end

    test "trying to join a bad topic fails", c do
      topic = c.bad_topic

      :ok = join(c.pid, topic)

      assert_receive {@client, :topic_closed, ^topic,
                      {:failed_to_join, %{"bad" => "join"}}},
                     @timeout
    end

    test "we may receive a reply which is just an atom", c do
      topic = c.good_topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "ack", %{}})

      assert_receive {@client, :received_reply, _ref, :ok}, @timeout
    end
  end

  defp join(pid, topic) do
    GenServer.cast(pid, {:join, topic, %{test_pid: pid_string()}})
  end
end
