defmodule SlipstreamWeb.PingChannel do
  use SlipstreamWeb, :channel

  @moduledoc false

  def join("echo:" <> _, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{"pong" => "pong"}}, socket}
  end

  def terminate(reason, socket) do
    IO.inspect(reason, label: "crashing")
    {:ok, socket}
  end
end
