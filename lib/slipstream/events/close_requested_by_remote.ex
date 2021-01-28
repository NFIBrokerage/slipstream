defmodule Slipstream.Events.CloseRequestedByRemote do
  @moduledoc false

  # the remote server has told the client it needs to disconnect

  defstruct []
end

defimpl Slipstream.Callback, for: Slipstream.Events.CloseRequestedByRemote do
  def dispatch(event, socket) do
    {:handle_disconnected, [:closed_by_remote, socket]}
  end
end
