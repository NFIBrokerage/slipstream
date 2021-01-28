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

    {:ok, reconnect(socket)}
  end

  @impl Slipstream
  def handle_join(topic, response, socket) do
    IO.inspect({self(), topic, response}, label: "handle_join/3")

    # _ref = push(socket, topic, "foo", %{})

    # await_reply(socket, ref) |> IO.inspect(label: "sync reply")

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
  def handle_info(message, socket) do
    IO.inspect(message, label: "example handle_info/2")

    {:noreply, socket}
  end

  @impl Slipstream
  def handle_topic_close(topic, message, socket) do
    IO.inspect(message, label: "handle_topic_close/2")

    {:ok, rejoin(socket, topic)}
  end
end
