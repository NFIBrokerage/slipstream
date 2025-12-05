defmodule Slipstream.Callback do
  @moduledoc false

  # maps events to the proper callback function and arguments

  alias Slipstream.{Events, Socket, TelemetryHelper}

  @known_callbacks [{:__no_op__, 2} | Slipstream.behaviour_info(:callbacks)]

  # dispatch an incoming event to a module's callback implementations
  # if the module does not implement the callback, it will be sent instead to
  # the default implementation in Slipstream.Default
  @spec dispatch(
          module :: module(),
          event :: struct(),
          socket :: Socket.t()
        ) ::
          {:noreply, new_socket}
          | {:noreply, new_socket, timeout() | :hibernate | {:continue, term()}}
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

    TelemetryHelper.wrap_dispatch(dispatch_module, function, args, fn ->
      apply(dispatch_module, function, args)
      |> handle_callback_return()
    end)
  end

  # coveralls-ignore-start
  defp handle_callback_return({:ok, %Socket{} = socket}), do: {:noreply, socket}

  defp handle_callback_return({:ok, %Socket{} = socket, others}),
    do: {:noreply, socket, others}

  defp handle_callback_return({:noreply, %Socket{}} = return), do: return

  defp handle_callback_return({:noreply, %Socket{}, _others} = return),
    do: return

  defp handle_callback_return({:stop, _reason, %Socket{}} = return), do: return

  # coveralls-ignore-stop

  # ensures at compile-time that the callback exists. useful for development
  @spec callback(atom(), [any()]) :: {atom(), [any() | Socket.t()]}
  defmacrop callback(name, args) do
    # add one for the socket
    # note that `args` needs to be a compile-time list for this to work
    arity = length(args) + 1

    if {name, arity} not in @known_callbacks do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "cannot wrap unknown callback #{name}/#{arity}"
    end

    quote do
      {unquote(name), unquote(args)}
    end
  end

  @spec determine_callback(event :: struct(), socket :: Socket.t()) ::
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
      Events.TopicJoinFailed.to_reason(event)
    ]
  end

  defp _determine_callback(%Events.TopicJoinClosed{} = event) do
    callback :handle_topic_close, [event.topic, event.reason]
  end

  defp _determine_callback(%Events.TopicLeft{} = event) do
    callback :handle_leave, [event.topic]
  end

  # coveralls-ignore-start
  defp _determine_callback(%Events.TopicLeaveAccepted{} = event) do
    callback :__no_op__, [event]
  end

  # coveralls-ignore-stop

  defp _determine_callback(%Events.ReplyReceived{} = event) do
    callback :handle_reply, [event.ref, event.reply]
  end

  defp _determine_callback(%Events.MessageReceived{} = event) do
    callback :handle_message, [event.topic, event.event, event.payload]
  end

  # we'll have to write a fixture that either accepts config from the
  # test process or write one designed to fail on connect to test this
  # seems like a lot of work for something that's easy to test with the
  # synchronous API
  # coveralls-ignore-start
  defp _determine_callback(%Events.ChannelConnectFailed{} = event) do
    callback :handle_disconnect, [{:error, event.reason}]
  end

  # coveralls-ignore-stop

  defp _determine_callback(%Events.ChannelClosed{} = event) do
    callback :handle_disconnect, [event.reason]
  end

  # coveralls-ignore-start
  defp _determine_callback(event) do
    callback :handle_info, [event]
  end

  # coveralls-ignore-stop
end
