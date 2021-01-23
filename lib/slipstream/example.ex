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
    connect!(uri: "ws://localhost:4000/socket/websocket")

    {:ok, %{}}
  end

  @impl Slipstream
  def handle_connect(state) do
    IO.inspect(self(), label: "connected")

    join("echo:foo")

    {:noreply, state}
  end

  @impl Slipstream
  def handle_join(success?, response, state) do
    IO.inspect({self(), success?, response}, label: "handle_join/3")

    {:noreply, state}
  end

  @impl Slipstream
  def handle_info(message, state) do
    IO.inspect(message, label: "handle_info/2")

    {:noreply, state}
  end
end
