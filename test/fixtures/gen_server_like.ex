defmodule Slipstream.GenServerLike do
  @moduledoc """
  An example slipstream server that emulates a basic GenServer
  """

  use Slipstream

  def start_link(arg) do
    Slipstream.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl Slipstream
  def init(_arg) do
    {:ok, new_socket()}
  end

  @impl Slipstream
  def handle_call(:sync_call, _from, socket) do
    {:reply, {:ok, :sync_call}, socket}
  end

  def handle_call(:async_call, from, socket) do
    send(self(), :reply)

    {:noreply, assign(socket, :from, from)}
  end

  @impl Slipstream
  def handle_info({:info, pid}, socket) do
    send(pid, :info_received)

    {:noreply, socket}
  end

  def handle_info(:reply, socket) do
    GenServer.reply(socket.assigns.from, {:ok, :async_call})

    {:noreply, socket}
  end

  @impl Slipstream
  def handle_cast({:cast, pid}, socket) do
    send(pid, :cast_received)

    {:noreply, socket}
  end
end
