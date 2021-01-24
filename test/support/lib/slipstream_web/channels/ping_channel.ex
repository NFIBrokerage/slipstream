defmodule SlipstreamWeb.PingChannel do
  use SlipstreamWeb, :channel

  @moduledoc false

  def join("echo:" <> _, _payload, socket) do
    IO.inspect(self(), label: inspect(__MODULE__))
    {:ok, socket}
  end

  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{"pong" => "pong"}}, socket}
  end

  def handle_in("foo", _params, socket) do
    {:noreply, socket}
  end

  def terminate(reason, socket) do
    IO.inspect(reason, label: "#{inspect(__MODULE__)} crashing")
    {:ok, socket}
  end
end
