defmodule Slipstream.Commands do
  @moduledoc false

  # commands are messages sent from the server process to the connection process
  # that request that the connection process do something

  # commands usually result **indirectly** in events
  # i.e. the command tells the connection to do something, the connection does
  # it, and that change is picked up by the connection process and emitted as
  # an event

  # this can either be used to
  # 1. wrap commands in a marker that clearly states that it's a slipstream
  #    command
  # 2. match on a command in a receive/2 or function definition expression,
  #    ensuring that the pattern is indeed a slipstream command
  defmacro command(command_pattern) do
    quote do
      {:__slipstream_command__, unquote(command_pattern)}
    end
  end
end
