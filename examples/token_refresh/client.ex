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
    new_socket()
    |> assign(:config, config)
    |> assign_token()
    |> connect(config_with_token())
  end

  defp assign_token(socket) do
    token = "get_token_from_service"
    assign(socket, :token, token)
  end

  defp config_with_token(socket) do
    uri = socket.assigns.config
    |> Keyword.get(:uri)
    |> URI.parse()
    |> Map.put(:query, "token=#{socket.assigns.token}")
    |> URI.to_string()

    Keyword.put(config, :uri, uri)
  end

  @impl Slipstream
  def handle_disconnect(:403, socket) do
    # token is no longer valid, refresh token and connect

    socket
    |> assign_token()
    |> connect(config_with_token())
  end
end

