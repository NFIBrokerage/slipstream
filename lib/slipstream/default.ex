defmodule Slipstream.Default do
  @moduledoc false

  # a module providing default implementations for Slipstream callbacks

  @behaviour Slipstream

  import Slipstream, only: [reconnect: 1, rejoin: 2]

  @impl Slipstream
  def init(args), do: {:ok, args}

  @impl Slipstream
  def terminate(_reason, _socket), do: :ok

  @impl Slipstream
  def handle_info(_message, socket), do: {:noreply, socket}

  @impl Slipstream
  def handle_connect(socket), do: {:ok, socket}

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    {:ok, _socket} = reconnect(socket)
  end

  @impl Slipstream
  def handle_join(_success?, _response, socket), do: {:ok, socket}

  @impl Slipstream
  def handle_message(_topic, _event, _message, socket), do: {:ok, socket}

  @impl Slipstream
  def handle_reply(_ref, _reply, socket), do: {:ok, socket}

  @impl Slipstream
  def handle_topic_close(topic, _message, socket) do
    {:ok, _socket} = rejoin(socket, topic)
  end

  def __no_op__(_event, socket), do: {:ok, socket}
end
