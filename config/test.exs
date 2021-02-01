use Mix.Config

config :slipstream, SlipstreamWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4001],
  secret_key_base:
    "gce/NurgQlG1YfPhRdPW+TCmrZSOGd6e6Wt7E2Fb36ODjW1eB6vxT9whakCmYSnw",
  render_errors: [
    view: SlipstreamWeb.ErrorView,
    accepts: ~w(json),
    layout: false
  ],
  pubsub_server: Slipstream.PubSub,
  server: true

config :logger, level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :slipstream, Slipstream.GoodExample,
  uri: "ws://localhost:4001/socket/websocket"

config :slipstream, Slipstream.TestModeClient,
  # N.B. this client will _not_ connect
  uri: "ws://localhost:54321/socket/websocket",
  test_mode?: true

config :slipstream, :gun_client, :gun
