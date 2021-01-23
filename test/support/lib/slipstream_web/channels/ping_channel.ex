defmodule SlipstreamWeb.PingChannel do
  use SlipstreamWeb, :channel

  def join("echo:" <> _, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("ping", _params, socket) do
    {:reply, "pong", socket}
  end
end
