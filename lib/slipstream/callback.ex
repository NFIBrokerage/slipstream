defprotocol Slipstream.Callback do
  @moduledoc false

  # A protocol for dispatching Slipstream.Messages to their associated
  # Slipstream callback
  # e.g. a Slipstream.Messages.Reply should be dispatched to
  # `c:Slipstream.handle_reply/3`

  def dispatch(message, state)
end
