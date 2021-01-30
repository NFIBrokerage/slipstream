defmodule Slipstream.PidHelpers do
  @moduledoc """
  Helpers for dealing with pids

  Most of the tests for slipstream involve processes sending eachother messages.
  Some of these pids are sent over-the-wire as strings, so we need helper
  functions to serialize and deserialize them.
  """

  def pid_string do
    [pid_string] = Regex.run(~r/[\d\.]+/, inspect(self()))

    pid_string
  end

  # N.B. this is a re-implementation of Iex.Helpers.pid/1
  # I thought this was a Kernel function :P
  def pid(str), do: :erlang.list_to_pid('<#{str}>')
end
