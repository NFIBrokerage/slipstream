defmodule MyApp.GracefulStartupClient do
  use Slipstream

  @moduledoc """
  A slipstream client that gracefully handles misconfiguration errors on
  start-up
  """

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(_args) do
    config = Application.fetch_env!(:my_app, __MODULE__)
    {:ok, connect!(config)}
  end
end
