defmodule SlipstreamWeb.TestChannel do
  use SlipstreamWeb, :channel

  @moduledoc false

  def join("test:good", _payload, socket) do
    {:ok, socket}
  end

  def join("test:crash", _payload, _socket) do
    {:error, %{"bad" => "join"}}
  end

  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{"pong" => "pong"}}, socket}
  end

  def handle_in("push to me", _params, socket) do
    push(socket, "foo", %{"bar" => "baz"})

    {:noreply, socket}
  end

  def handle_in("error tuple", _params, socket) do
    {:reply, {:error, %{"failure?" => true}}, socket}
  end

  def handle_in("raise", _params, _socket) do
    raise "oooooooohnnnnnnnnnnnnnoooooooooooooooooooooooooooooo"
  end

  def terminate(_reason, _socket) do
    IO.puts("#{inspect(__MODULE__)} shutting down")

    :ok
  end
end
