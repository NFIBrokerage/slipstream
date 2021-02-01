defmodule Slipstream.SynchronicityTest do
  use ExUnit.Case, async: true

  import Slipstream
  import Slipstream.Socket
  import Slipstream.PidHelpers
  alias Slipstream.Socket

  @moduletag :capture_log

  @server SlipstreamWeb.TestChannel

  setup do
    [config: Application.fetch_env!(:slipstream, Slipstream.GoodExample)]
  end

  describe "given an open connection to a remote websocket server" do
    setup c do
      [socket: c.config |> connect!() |> await_connect!()]
    end

    test "the socket is alive", c do
      assert c.socket |> connected?()
    end

    test "we can join and leave synchronously", c do
      topic = "test:good"

      assert {:ok, %Socket{} = socket} =
               c.socket
               |> join(topic, %{test_pid: pid_string()})
               |> await_join(topic)

      assert joined?(socket, topic)

      assert {:ok, %Socket{} = socket} =
               socket
               |> leave(topic)
               |> await_leave(topic)

      refute joined?(socket, topic)

      assert %Socket{} =
               socket =
               socket
               |> join(topic, %{test_pid: pid_string()})
               |> await_join!(topic)

      assert joined?(socket, topic)

      assert %Socket{} =
               socket =
               socket
               |> leave(topic)
               |> await_leave!(topic)

      refute joined?(socket, topic)
    end

    test "the socket can be disconnected synchronously", c do
      assert {:ok, %Socket{} = socket} =
               c.socket
               |> disconnect()
               |> await_disconnect()

      refute connected?(socket)
    end

    test "the socket can be disconnected synchronously with the bang function",
         c do
      assert %Socket{} =
               socket =
               c.socket
               |> disconnect()
               |> await_disconnect!()

      refute connected?(socket)
    end

    test "we may request garbage collection", c do
      assert collect_garbage(c.socket) == :ok
    end
  end

  describe "given a connection joined to a good topic" do
    setup c do
      topic = "test:good"
      {:ok, socket} = connect(c.config)
      {:ok, socket} = await_connect(socket)

      {:ok, socket} =
        socket
        |> join(topic, %{test_pid: pid_string()})
        |> await_join(topic)

      [socket: socket, topic: topic]
    end

    test "a message may be pushed synchronously", c do
      topic = c.topic
      event = "quicksand"
      params = %{"a" => "b"}
      push!(c.socket, topic, event, params)

      assert_receive {@server, :in, ^topic, ^event, ^params}
    end

    test "a message may be received synchronously", c do
      topic = c.topic
      event = "push to me"
      params = %{}

      push!(c.socket, topic, event, params)

      assert {:ok, ^topic, "foo", %{"bar" => "baz"}} =
               await_message(^topic, "foo", %{})

      push!(c.socket, topic, event, params)

      assert {^topic, "foo", %{"bar" => "baz"}} =
               await_message!(^topic, "foo", %{})
    end

    test "a reply can be received synchronously", c do
      topic = c.topic
      event = "ping"
      params = %{}

      assert {:ok, %{"pong" => "pong"}} =
               c.socket
               |> push!(topic, event, params)
               |> await_reply()

      assert {:ok, %{"pong" => "pong"}} =
               c.socket
               |> push!(topic, event, params)
               |> await_reply!()
    end
  end

  test """
  when trying to connect to a port with nothing running on it,
  the channel connection fails with timeout
  """ do
    assert {:error, :timeout} =
             connect!(uri: "ws://localhost:4000/socket/websocket")
             |> await_connect()
  end

  test """
  when trying to connect to a url that is not a websocket endpoint,
  the channel connection fails with 404
  """ do
    assert {:error, reason} =
             connect!(uri: "ws://localhost:4001/socket")
             |> await_connect()

    assert reason.resp_headers |> is_list()
    assert reason.status_code == 404
    assert reason.response == %{"errors" => %{"detail" => "Not Found"}}
    assert reason.request_id |> is_binary()
  end
end
