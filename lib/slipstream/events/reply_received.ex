defmodule Slipstream.Events.ReplyReceived do
  @moduledoc false

  @type t :: %__MODULE__{}

  # a message that says that a push from the client has been replied-to by
  # the server

  defstruct [:topic, :reply, :ref]

  def to_reply(%{"status" => status, "response" => response})
      when status in ["ok", "error"] and map_size(response) == 0 do
    String.to_atom(status)
  end

  def to_reply(%{"status" => status, "response" => response})
      when status in ["ok", "error"] do
    {String.to_atom(status), response}
  end
end
