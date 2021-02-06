defmodule Slipstream.ConnectionSupervisor do
  @moduledoc """
  A supervisor for connection processes

  #{inspect(__MODULE__)} is a simple module-based `DynamicSupervisor` which
  is used to supervise connection processes. As such, you may track the number
  of connection processes with `DynamicSupervisor.count_children/1`.
  #{inspect(__MODULE__)} uses its module name as the DynamicSupervisor name,
  so you may pass `#{inspect(__MODULE__)}` into any DynamicSupervisor function.

  ## Examples

      iex> #{inspect(__MODULE__)} |> DynamicSupervisor.count_children()
      %{active: 15, specs: 15, supervisors: 0, workers: 15}
  """

  use DynamicSupervisor

  @doc false
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc false
  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
