defmodule MyApp.RepeaterClient do
  @moduledoc """
  A repeater-kind of client which re-broadcasts messages from another service
  into this service's endpoint
  """

  @endpoint SlipstreamWeb.Endpoint
  @topic "rooms:lobby"

  use Slipstream

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config), do: {:ok, connect!(config)}

  @impl Slipstream
  def handle_connect(socket), do: {:ok, join(socket, @topic)}

  @impl Slipstream
  def handle_message(topic, event, payload, socket) do
    @endpoint.broadcast(topic, event, payload)

    {:ok, socket}
  end
end
