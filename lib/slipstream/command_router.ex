defmodule Slipstream.CommandRouter do
  @moduledoc false

  # Implements how a command is routed.
  # Note that many commands are simply forwarded to the connection process
  # for further handling.
  # For other commands like OpenConnection, there is no connection process to
  # send to

  alias Slipstream.Commands.{
    OpenConnection,
    JoinTopic,
    LeaveTopic,
    PushMessage
  }

  alias Slipstream.Socket

  @forwarded_command_types [
    JoinTopic,
    LeaveTopic
  ]

  @spec route_command(struct()) :: any()
  def route_command(command)

  def route_command(%OpenConnection{} = cmd) do
    DynamicSupervisor.start_child(
      Slipstream.ConnectionSupervisor,
      {Slipstream.Connection, cmd}
    )
  end

  # forward the commands to the connection process
  def route_command(%command_type{socket: socket} = cmd) when command_type in @forwarded_command_types do
    Socket.send(socket, cmd)
  end

  # this one is a synchronous push with a reply from the connection process
  def route_command(%PushMessage{socket: socket} = cmd) do
    Socket.call(socket, cmd, cmd.timeout)
  end
end
