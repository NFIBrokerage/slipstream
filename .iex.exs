[
  # Start the PubSub system
  {Phoenix.PubSub, name: Slipstream.PubSub},
  # Start the Endpoint (http/https)
  SlipstreamWeb.Endpoint
]
|> Supervisor.start_link(strategy: :one_for_one)
