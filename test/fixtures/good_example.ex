defmodule Slipstream.GoodExample do
  @moduledoc """
  An example slipstream socket client
  """

  use Slipstream, restart: :transient

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts)
  end

  @impl Slipstream
  def init(opts) do
    {test_proc, opts} = Keyword.pop!(opts, :pid)
    opts = Keyword.put_new(opts, :uri, "ws://localhost:4001/socket/websocket")

    socket =
      opts
      |> connect!()
      |> assign(:test_proc, test_proc)

    test_ref = Process.monitor(test_proc)

    {:ok, assign(socket, :test_ref, test_ref)}
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
  def handle_info(
        {:DOWN, ref, :process, pid, _reason},
        %{assigns: %{test_proc: pid, test_ref: ref}} = socket
      ) do
    # cleans up after the test process exits
    {:stop, :normal, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_cast({:join, topic, params}, socket) do
    {:noreply, join(socket, topic, params)}
  end

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
