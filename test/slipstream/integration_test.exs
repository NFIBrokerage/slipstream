defmodule Slipstream.IntegrationTest do
  use ExUnit.Case, async: true

  # tests a slipstream example fixture against the phoenix client running in
  # test mode

  @moduletag :capture_log

  @timeout 500

  @client Slipstream.GoodExample
  @server SlipstreamWeb.TestChannel

  describe "given a connection has been established through the #{@client}" do
    setup do
      client_pid = start_supervised!({@client, self()})

      assert_receive {@client, :connected}, @timeout

      [pid: client_pid, topic: "test:good"]
    end

    test "joining a good channel works", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout
    end

    test "duplicate joins do not result in an actual duplicate join", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = join(c.pid, topic)
      refute_receive {@client, :joined, ^topic, _reply}, @timeout
    end

    test "once a channel is joined it can be left", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      assert_receive {@client, :left, ^topic}, @timeout
    end

    test "once a channel is left, you cannot duplicate the leave", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      assert_receive {@client, :left, ^topic}, @timeout

      :ok = GenServer.cast(c.pid, {:leave, topic})
      refute_receive {@client, :left, ^topic}, @timeout
    end

    test "a message may be pushed to the remote", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "quicksand", %{}})
      assert_receive {@server, :in, ^topic, "quicksand", %{}}, @timeout
    end

    test "if a topic is not yet joined, you may not push a message", c do
      topic = c.topic

      :ok = GenServer.cast(c.pid, {:push, topic, "quicksand", %{}})
      refute_receive {@server, :in, ^topic, "quicksand", %{}}, @timeout
    end

    test "a message may be received from the server", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "push to me", %{}})

      assert_receive {@client, :received_message, ^topic, "foo", %{"bar" => "baz"}}, @timeout
    end

    test "a reply may be received from the server", c do
      topic = c.topic

      :ok = join(c.pid, topic)
      assert_receive {@client, :joined, ^topic, _reply}, @timeout

      :ok = GenServer.cast(c.pid, {:push, topic, "ping", %{}})

      assert_receive {@client, :received_reply, _ref, {:ok, %{"pong" => "pong"}}}, @timeout
    end

    test "a connection may be disconnected", c do
      :ok = GenServer.cast(c.pid, :disconnect)
      assert_receive {@client, :disconnected, reason}, @timeout
      assert reason == :client_disconnect_requested
    end
  end

  defp join(pid, topic) do
    GenServer.cast(pid, {:join, topic, %{test_pid: pid_string()}})
  end

  def pid_string do
    [pid_string] = Regex.run(~r/[\d\.]+/, inspect(self()))

    pid_string
  end
end
