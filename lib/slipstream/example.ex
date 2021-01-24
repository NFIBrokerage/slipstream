defmodule Slipstream.Example do
  @moduledoc """
  An example slipstream socket client
  """

  # use Slipstream
  import Slipstream

  @behaviour Slipstream

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(_args) do
    connect!(
      uri: "ws://localhost:4000/socket/websocket",
      heartbeat_interval_msec: 10_000
    )

    {:ok, %{}}
  end

  @impl Slipstream
  def handle_connect(state) do
    IO.inspect(self(), label: "connected")

    join("echo:foo")

    {:ok, state}
  end

  @impl Slipstream
  def handle_disconnect(reason, state) do
    IO.inspect(reason, label: "handle_disconnect/2")

    reconnect()

    {:ok, state}
  end

  @impl Slipstream
  def handle_join(status, response, state) do
    IO.inspect({self(), status, response}, label: "handle_join/3")

    push("foo", %{})

    {:ok, state}
  end

  @impl Slipstream
  def handle_message(event, message, state) do
    IO.inspect({event, message}, label: "handle_message/2")

    {:ok, state}
  end

  @impl Slipstream
  def handle_reply(ref, reply, state) do
    IO.inspect({ref, reply}, label: "handle_reply/3")

    {:ok, state}
  end

  @impl Slipstream
  def handle_info(message, state) do
    IO.inspect(message, label: "handle_info/2")

    {:noreply, state}
  end

  @impl Slipstream
  def handle_channel_close(message, state) do
    IO.inspect(message, label: "handle_channel_close/2")

    rejoin()

    {:ok, state}
  end
end
