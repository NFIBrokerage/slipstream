defmodule MyApp.RejoinOnReconnectClient do
  use Slipstream

  def join(topic) do
    GenServer.cast(__MODULE__, {:join, topic})
  end

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config) do
    {:ok, connect!(config)}
  end

  @impl Slipstream
  def handle_cast({:join, topic}, socket) do
    {:noreply, join(socket, topic)}
  end
end
