defmodule MyApp.RejoinOnReconnectClient do
  @moduledoc """
  A client which re-joins all topics it had joined after a reconnection
  """

  use Slipstream

  def join(topic) do
    GenServer.cast(__MODULE__, {:join, topic})
  end

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config) do
    socket =
      config
      |> connect!()
      |> assign(:topics, [])

    {:ok, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    socket =
      socket.assigns.topics
      |> Enum.reduce(socket, fn topic, socket ->
        case rejoin(socket, topic) do
          {:ok, socket} -> socket
          {:error, _reason} -> socket
        end
      end)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_cast({:join, new_topic}, socket) do
    socket =
      socket
      |> update(:topics, fn existing_topics -> [new_topic | existing_topics] end)
      |> join(new_topic)

    {:noreply, socket}
  end
end
