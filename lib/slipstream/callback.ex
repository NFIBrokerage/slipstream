defmodule Slipstream.Callback do
  @moduledoc false

  # maps events to the proper callback function and arguments

  alias Slipstream.{Events, Socket}

  # dispatch an incoming event to a module's callback implementations
  # if the module does not implement the callback, it will be sent instead to
  # the default implementation in Slipstream.Default
  @spec dispatch(
          module :: module(),
          event :: struct(),
          socket :: Socket.t()
        ) ::
          {:ok, new_socket}
          | {:ok, new_socket, timeout() | :hibernate | {:continue, term()}}
          | {:stop, reason :: term(), new_socket}
        when new_socket: term()
  def dispatch(module, event, socket) do
    socket = Socket.apply_event(socket, event)
    {function, args} = determine_callback(event, socket)

    dispatch_module =
      if function_exported?(module, function, length(args)) do
        module
      else
        Slipstream.Default
      end

    case apply(dispatch_module, function, args) do
      {:ok, socket} ->
        {:noreply, socket}

      {:ok, socket, other_stuff} ->
        {:noreply, socket, other_stuff}

      {:stop, _reason, _socket} = stop ->
        stop
        # YARD catchall with a helpful error message?
    end
  end

  # ensures at compile-time that the callback exists. useful for development
  defmacrop callback(name, args) do
    # add one for the socket
    # note that `args` needs to be a compile-time list for this to work
    arity = length(args) + 1

    unless {name, arity} in Slipstream.behaviour_info(:callbacks) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "cannot wrap unknown callback #{name}/#{arity}"
    end

    quote do
      {unquote(name), unquote(args)}
    end
  end

  @spec determine_callback(event :: struct(), socket :: Slipstream.Socket.t()) ::
          {atom(), list(any())}
  def determine_callback(event, socket) do
    {name, args} = _determine_callback(event)

    # inject socket as last arg, always
    {name, args ++ [socket]}
  end

  defp _determine_callback(%Events.ChannelConnected{}) do
    callback :handle_connect, []
  end

  defp _determine_callback(%Events.TopicJoinSucceeded{} = event) do
    callback :handle_join, [event.topic, event.response]
  end

  defp _determine_callback(%Events.TopicJoinFailed{} = event) do
    callback :handle_topic_close, [
      event.topic,
      {:failed_to_join, event.response}
    ]
  end

  defp _determine_callback(%Events.TopicLeft{} = event) do
    callback :handle_topic_close, [event.topic, :left]
  end

  defp _determine_callback(%Events.ReplyReceived{} = event) do
    callback :handle_reply, [
      {event.topic, event.ref},
      Events.ReplyReceived.to_reply(event)
    ]
  end

  defp _determine_callback(%Events.MessageReceived{} = event) do
    callback :handle_message, [event.topic, event.event, event.payload]
  end

  defp _determine_callback(%Events.CloseRequestedByRemote{} = _event) do
    callback :handle_disconnect, [:closed_by_remote]
  end

  defp _determine_callback(%Events.ChannelConnectFailed{} = event) do
    callback :handle_disconnect, [Events.ChannelConnectFailed.to_reason(event)]
  end

  defp _determine_callback(%Events.ChannelClosed{} = event) do
    callback :handle_disconnect, [event.reason]
  end

  defp _determine_callback(event) do
    callback :handle_info, [event]
  end
end
