defmodule Slipstream.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Slipstream.ConnectionSupervisor
    ]

    opts = [strategy: :one_for_one, name: Slipstream.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
