defmodule Slipstream.Events.ReplyReceived do
  @moduledoc false

  # a message that says that a push from the client has been replied-to by
  # the server

  defstruct [:topic, :status, :response, :ref]

  def to_reply(%__MODULE__{status: status, response: response})
      when status in [:ok, :error] and map_size(response) == 0 do
    status
  end

  def to_reply(%__MODULE__{status: status, response: response})
      when status in [:ok, :error] do
    {status, response}
  end
end
