defmodule Slipstream.ConnectionSupervisor do
  @moduledoc """
  A supervisor for connection processes

  #{inspect(__MODULE__)} is a simple module-based `DynamicSupervisor` which
  is used to supervise connection processes. As such, you may track the number
  of connection processes with `DynamicSupervisor.count_children/1`.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
