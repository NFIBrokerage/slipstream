defmodule SlipstreamWeb.TestChannel do
  use SlipstreamWeb, :channel

  require Logger

  @moduledoc false

  def join("test:good", %{"test_pid" => proc_string}, socket) do
    socket =
      socket
      |> assign(:test_proc, pid(proc_string))
      |> assign(:topic, "test:good")

    {:ok, socket}
  end

  def join("test:crash", _payload, _socket) do
    {:error, %{"bad" => "join"}}
  end

  # just swallows the request
  def handle_in("quicksand", params, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :in, socket.assigns.topic, "quicksand", params})

    {:noreply, socket}
  end

  # responds to the request
  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{"pong" => "pong"}}, socket}
  end

  # responds, but not with a reply
  # just an async send
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

  # N.B. this is a re-implementation of Iex.Helpers.pid/1
  # I thought this was a Kernel function :P
  defp pid(str), do: :erlang.list_to_pid('<#{str}>')
end
