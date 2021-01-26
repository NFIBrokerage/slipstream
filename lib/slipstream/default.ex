defmodule Slipstream.Default do
  @moduledoc false

  # a module providing default implementations for Slipstream callbacks

  @behaviour Slipstream

  import Slipstream, only: [reconnect: 0, rejoin: 0]

  @impl Slipstream
  def init(args), do: {:ok, args}

  @impl Slipstream
  def terminate(_reason, _state), do: :ok

  @impl Slipstream
  def handle_info(_message, state), do: {:noreply, state}

  @impl Slipstream
  def handle_connect(state), do: {:ok, state}

  @impl Slipstream
  def handle_disconnect(_reason, state) do
    reconnect()

    {:ok, state}
  end

  @impl Slipstream
  def handle_join(_success?, _response, state), do: {:ok, state}

  @impl Slipstream
  def handle_message(_event, _message, state), do: {:noreply, state}

  @impl Slipstream
  def handle_reply(_ref, _reply, state), do: {:ok, state}

  @impl Slipstream
  def handle_channel_close(_message, state) do
    rejoin()

    {:ok, state}
  end
end
