defmodule Slipstream.SocketTest.Server do
  @moduledoc """
  A test-server data structure

  Note that this Server is not an actual server: no (network) ports are
  consumed and nothing is listening for websocket requests.
  """

  @typedoc """
  A test-server data structure

  This type encapsulates everything a testing server needs to know: the pid
  of the test process and the client pid/name.
  """
  @typedoc since: "0.2.0"
  @type t :: %__MODULE__{
    pid: pid(),
    client: pid | GenServer.name()
  }

  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: []}
  end

  defstruct [:pid, :client]

  def new(pid), do: %__MODULE__{pid: pid}
end
