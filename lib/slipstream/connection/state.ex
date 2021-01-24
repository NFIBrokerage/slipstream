defmodule Slipstream.Connection.State do
  @moduledoc false

  # a struct for storing the internal state of a Slipstream.Connection
  # process

  # the module which implements the Slipstream behaviour is hereby known
  # as the implementor

  defstruct [
    :implementor,
    :implementor_state,
    :connection_configuration,
    :connection_ref,
    :connection_conn,
    :topic,
    :join_params,
    :heartbeat_timer,
    :heartbeat_ref,
    :join_ref,
    reconnect_try_number: 0,
    rejoin_try_number: 0
  ]

  @known_callbacks Slipstream.behaviour_info(:callbacks)

  # a macro which wraps a call to the implementor's callbacks
  # if the implementor does not implement the `callback_to_invoke`, the callback
  # will be invoked by the default implementation defined in Slipstream.Default
  defmacro callback(state, callback_to_invoke, arguments) do
    # N.B. this assumes that arguments is a compile-time list
    # we don't **need** this, but it helps do some compile-time checks that are
    # helpful with development.
    # the +1 is for the implementor state we inject at the end
    arity = length(arguments) + 1

    unless known_callback?(callback_to_invoke, arity) do
      raise CompileError,
        line: __CALLER__.line,
        file: __CALLER__.file,
        description:
          "cannot wrap unknown callback #{callback_to_invoke}/#{arity}"
    end

    quote do
      module_to_use =
        if function_exported?(
             unquote(state).implementor,
             unquote(callback_to_invoke),
             unquote(arity)
           ) do
          unquote(state).implementor
        else
          Slipstream.Default
        end

      module_to_use.unquote(callback_to_invoke)(
        unquote_splicing(arguments),
        unquote(state).implementor_state
      )
    end
  end

  defp known_callback?(func, arity) do
    {func, arity} in @known_callbacks
  end

  def increment_reconnect_counter(state) do
    increment(state, :reconnect_try_number)
  end

  def reset_reconnect_try_counter(state) do
    put_in(state.reconnect_try_number, 0)
  end

  def increment_rejoin_counter(state) do
    increment(state, :rejoin_try_number)
  end

  def reset_rejoin_try_counter(state) do
    put_in(state.rejoin_try_number, 0)
  end

  defp increment(map, key) do
    Map.update(map, key, 1, &(&1 + 1))
  end

  def reset_heartbeat(state) do
    %__MODULE__{state | heartbeat_ref: nil}
  end

  def cancel_heartbeat_timer(state) do
    if state.heartbeat_timer |> is_reference() do
      :timer.cancel(state.heartbeat_timer)
    end

    state
  end
end
