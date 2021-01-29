defmodule Slipstream.GoodExample do
  @moduledoc """
  An example slipstream socket client
  """

  use Slipstream, restart: :transient

  @topic "test:foo"
  @config Application.compile_env!(:slipstream, __MODULE__)

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts)
  end

  @impl Slipstream
  def init(test_proc) do
    socket =
      @config
      |> connect!()
      |> assign(:test_proc, test_proc)

    test_ref = Process.monitor(test_proc)

    {:ok, assign(socket, :test_ref, test_ref)}
  end

  @impl Slipstream
  def handle_connect(socket) do
    send(socket.assigns.test_proc, {__MODULE__, :connected})

    {:ok, join(socket, @topic)}
  end

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    send(socket.assigns.test_proc, {__MODULE__, :disconnected, reason})

    {:ok, _socket} = reconnect(socket)
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

  def handle_info(:leave, socket) do
    {:noreply, leave(socket, @topic)}
  end

  def handle_info(:disconnect, socket) do
    {:noreply, disconnect(socket)}
  end

  def handle_info(message, socket) do
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_topic_close(topic, message, socket) do
    send(
      socket.assigns.test_proc,
      {__MODULE__, :topic_closed, topic, message}
    )

    {:ok, _socket} = rejoin(socket, topic)
  end
end
