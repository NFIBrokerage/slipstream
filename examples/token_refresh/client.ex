defmodule MyApp.TokenRefreshClient do
  @moduledoc """
  A client which authenticates via token, and refreshes the token on 403.
  """

  use Slipstream

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config) do
    config = update_uri(config)

    new_socket()
    |> assign(:config, config)
    |> connect(config)
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    reconnect(socket)
  end

  @impl Slipstream
  def refresh_connection_config(_socket, config) do
    update_uri(config)
  end

  defp update_uri(config) do
    uri =
      config
      |> Keyword.get(:uri)
      |> URI.parse()
      |> Map.put(:query, "token=#{make_new_token()}")
      |> URI.to_string()

    Keyword.put(config, :uri, uri)
  end

  defp make_new_token(), do: "get_new_token_here"
end
