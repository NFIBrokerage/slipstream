defmodule Slipstream.Signatures do
  @moduledoc false

  # a signature in this context is a unique marker attached to a datastructure
  # that allows us to match on it

  # this can either be used to
  # 1. wrap events in a marker that clearly states that it's a slipstream
  #    event
  # 2. match on an event in a receive/2 or function definition expression,
  #    ensuring that the pattern is indeed a slipstream event
  defmacro event(event_pattern) do
    quote do
      {:__slipstream_event__, unquote(event_pattern)}
    end
  end

  # same for commands
  defmacro command(command_pattern) do
    quote do
      {:__slipstream_command__, unquote(command_pattern)}
    end
  end
end
