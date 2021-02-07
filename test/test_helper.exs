# starting a phoenix server locally for integration testing
[
  # Start the PubSub system
  {Phoenix.PubSub, name: Slipstream.PubSub},
  # Start the Endpoint (http/https)
  SlipstreamWeb.Endpoint
]
|> Supervisor.start_link(strategy: :one_for_one)

ExUnit.configure(assert_receive_timeout: 250, refute_receive_timeout: 300)
ExUnit.start()
