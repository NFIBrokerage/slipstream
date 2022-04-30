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
    |> connect_with_token()
  end

  defp make_new_token, do: "get_new_token_here"

  defp connect_with_token(socket) do
    new_token = make_new_token()

    socket =
      update(socket, :config, fn config ->
        uri =
          config
          |> Keyword.get(:uri)
          |> URI.parse()
          |> Map.put(:query, "token=#{new_token}")
          |> URI.to_string()

        Keyword.put(config, :uri, uri)
      end)

    connect(socket, socket.assigns.config)
  end

  @impl Slipstream
  def handle_disconnect({:error, {_, %{status_code: 403}}}, socket) do
    connect_with_token(socket)
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    reconnect(socket)
  end
end
