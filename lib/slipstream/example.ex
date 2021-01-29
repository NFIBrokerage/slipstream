defmodule Slipstream.Example do
  @moduledoc """
  An example slipstream socket client
  """

  use Slipstream

  @topic "echo:foo"

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(_args) do
    # N.B. {:ok, socket} = connect(..), which is a valid return spec for init/1
    connect(
      uri: "ws://localhost:4000/socket/websocket",
      heartbeat_interval_msec: 10_000
    )
  end

  @impl Slipstream
  def handle_connect(socket) do
    IO.puts("#{inspect(__MODULE__)} connected, joining #{@topic}")

    {:ok, join(socket, @topic)}
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    IO.inspect(reason, label: "handle_disconnect/2")

    {:ok, _socket} = reconnect(socket)
  end

  @impl Slipstream
  def handle_join(topic, response, socket) do
    IO.inspect({topic, response}, label: "handle_join/3")

    push!(socket, topic, "ping", %{})
    # |> await_reply!() |> IO.inspect(label: "response")

    # Process.send_after(self(), :leave, 3_000)
    Process.send_after(self(), :disconnect, 3_000)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(topic, event, message, socket) do
    IO.inspect({topic, event, message}, label: "handle_message/4")

    {:ok, socket}
  end

  @impl Slipstream
  def handle_reply(ref, reply, socket) do
    IO.inspect({ref, reply}, label: "handle_reply/3")

    {:ok, socket}
  end

  @impl Slipstream
  def handle_info(:leave, socket) do
    IO.puts "leaving the topic"

    {:noreply, leave(socket, @topic)}
  end

  def handle_info(:disconnect, socket) do
    IO.puts "disconnecting..."

    {:noreply, disconnect(socket)}
  end

  def handle_info(message, socket) do
    IO.inspect(message, label: "example handle_info/2")

    {:noreply, socket}
  end

  @impl Slipstream
  def handle_topic_close(topic, message, socket) do
    IO.inspect({topic, message}, label: "handle_topic_close/2")

    {:ok, _socket} = rejoin(socket, topic)
  end
end
