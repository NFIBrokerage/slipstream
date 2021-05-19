# coveralls-ignore-start
defmodule Slipstream.Default do
  @moduledoc false

  # a module providing default implementations for Slipstream callbacks

  @behaviour Slipstream

  import Slipstream, only: [reconnect: 1, rejoin: 2, disconnect: 1]

  @impl Slipstream
  def init(args), do: {:ok, args}

  @impl Slipstream
  def terminate(_reason, socket), do: disconnect(socket)

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

  @impl Slipstream
  def handle_leave(_topic, socket), do: {:ok, socket}

  def __no_op__(_event, socket), do: {:ok, socket}
end

# coveralls-ignore-stop
