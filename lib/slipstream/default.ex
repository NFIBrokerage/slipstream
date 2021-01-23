defmodule Slipstream.Default do
  @moduledoc false

  # a module providing default implementations for Slipstream callbacks

  @behaviour Slipstream

  @impl Slipstream
  def init(args), do: {:ok, args}

  @impl Slipstream
  def terminate(_reason, _state), do: :ok

  @impl Slipstream
  def handle_info(_message, state), do: {:noreply, state}

  @impl Slipstream
  def handle_connect(state), do: {:noreply, state}

  @impl Slipstream
  def handle_join(_success?, _response, state), do: {:noreply, state}
end
