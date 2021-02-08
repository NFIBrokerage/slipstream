defmodule MyApp.GenServerClient do
  @moduledoc """
  A slipstream client which shows off some of the GenServer functionality
  allowed with Slipstream
  """

  use Slipstream, restart: :temporary

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config) do
    {:ok, connect!(config)}
  end

  @impl Slipstream
  def handle_cast({:join, topic, params}, socket) do
    {:noreply, join(socket, topic, params)}
  end

  @impl Slipstream
  def handle_call(:ping, _from, socket) do
    {:reply, :pong, socket}
  end

  def handle_call({:join, topic, params}, from, socket) do
    socket =
      socket
      |> assign(:join_request, from)
      |> join(topic, params)

    {:noreply, socket}
  end

  @impl Slipstream
  def handle_join(_topic, response, socket) do
    GenServer.reply(socket.assigns.join_request, {:ok, response})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_info(:conclude_subscription, socket) do
    {:stop, :normal, disconnect(socket)}
  end
end
