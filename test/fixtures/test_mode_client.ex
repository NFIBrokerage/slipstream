defmodule Slipstream.TestModeClient do
  @moduledoc """
  A client that will start up in test mode and use the `Slipstream.SocketTest`
  testing framework
  """

  use Slipstream, restart: :transient

  @config Application.compile_env!(:slipstream, __MODULE__)

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(test_proc) do
    socket =
      @config
      |> connect!()
      |> assign(:test_proc, test_proc)

    {:ok, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    send(socket.assigns.test_proc, {__MODULE__, :connected})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_join(topic, response, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :joined, topic, response})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(topic, event, message, socket) do
    send(
      socket.assigns.test_proc,
      {__MODULE__, :received_message, topic, event, message}
    )

    {:ok, socket}
  end

  @impl Slipstream
  def handle_reply(ref, reply, socket) do
    send(
      socket.assigns.test_proc,
      {__MODULE__, :received_reply, ref, reply}
    )

    {:ok, socket}
  end

  @impl Slipstream
  def handle_cast({:leave, topic}, socket) do
    {:noreply, leave(socket, topic)}
  end

  def handle_cast({:push, topic, event, message}, socket) do
    push(socket, topic, event, message)

    {:noreply, socket}
  end

  def handle_cast(:disconnect, socket) do
    {:noreply, disconnect(socket)}
  end

  @impl Slipstream
  def handle_info({:join, topic, params}, socket) do
    # in order to test connect_and_join/5, in which the join does not happen
    # automatically after connection, but rather is queued up before the
    # accept_connect/2, we must defer our join request until we have
    # established a connection
    if connected?(socket) do
      {:noreply, join(socket, topic, params)}
    else
      Process.send_after(self(), {:join, topic, params}, 50)

      {:noreply, socket}
    end
  end

  @impl Slipstream
  def handle_leave(topic, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :left, topic})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_topic_close(topic, reason, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :topic_closed, topic, reason})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :disconnected, reason})

    {:ok, socket}
  end
end
