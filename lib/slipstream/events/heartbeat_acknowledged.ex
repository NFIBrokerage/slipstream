defmodule Slipstream.Events.HeartbeatAcknowledged do
  @moduledoc false

  @type t :: %__MODULE__{}

  # a message that says that our heartbeat request has been acknowledged

  # the only important part of this message is the ref, which we can use to
  # tell if the server is replying on-time
  # we generate a new ref for every heartbeat we send. if we get an ack for
  # a past ref or a future ref, we know that something is off and the
  # connection should be closed

  defstruct [:ref]
end
