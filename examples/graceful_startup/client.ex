defmodule MyApp.GracefulStartupClient do
  use Slipstream

  require Logger

  @moduledoc """
  A slipstream client that gracefully handles misconfiguration errors on
  start-up
  """

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(_args) do
    with {:ok, config} <- Application.fetch_env(:slipstream, __MODULE__),
         {:ok, socket} <- connect(config) do
      {:ok, socket}
    else
      :error ->
        Logger.warn("""
        Could not start #{inspect(__MODULE__)} because it is not configured
        """)

        :ignore

      {:error, reason} ->
        Logger.error("""
        Could not start #{inspect(__MODULE__)} because the configuration is invalid:
        #{inspect(reason)}
        """)

        :ignore
    end
  end
end
