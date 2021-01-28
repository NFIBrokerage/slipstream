defprotocol Slipstream.Callback do
  @moduledoc false

  # A protocol for dispatching Slipstream.Messages to their associated
  # Slipstream callback
  # e.g. a Slipstream.Messages.Reply should be dispatched to
  # `c:Slipstream.handle_reply/3`
  # so dispatch/2 would return {:handle_reply, args} with args being of length
  # 3 and having socket as the last argument

  def dispatch(event, socket)
end

defimpl Slipstream.Callback, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    callback = Keyword.fetch!(opts, :callback)
    arg_keys = Keyword.get(opts, :args, [])

    quote do
      defimpl Slipstream.Callback, for: unquote(module) do
        def dispatch(event, socket) do
          args = Enum.map(unquote(arg_keys), &Map.fetch!(event, &1))

          {unquote(callback), args ++ [socket]}
        end
      end
    end
  end

  def dispatch(event, socket) do
    {:handle_info, [event, socket]}
  end
end
