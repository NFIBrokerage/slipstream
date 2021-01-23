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
    join_ref: 0,
    current_ref: 0,
    heartbeat_ref: 0
  ]

  @known_callbacks Slipstream.behaviour_info(:callbacks)

  defmacro callback(state, callback_to_invoke, arguments) do
    # N.B. this assumes that arguments is a compile-time list
    # we don't **need** this, but it helps do some compile-time checks that are
    # helpful with development.
    arity = length(arguments)

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
             unquote(length(arguments))
           ) do
          unquote(state).implementor
        else
          Slipstream.Default
        end

      module_to_use.unquote(callback_to_invoke)(unquote_splicing(arguments))
    end
  end

  defp known_callback?(func, arity) do
    {func, arity} in @known_callbacks
  end

  def put_next_ref(state) do
    update_in(state.current_ref, 1, &(&1 + 1))
  end
end
