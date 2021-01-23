# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :slipstream, SlipstreamWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "gce/NurgQlG1YfPhRdPW+TCmrZSOGd6e6Wt7E2Fb36ODjW1eB6vxT9whakCmYSnw",
  render_errors: [view: SlipstreamWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Slipstream.PubSub,
  live_view: [signing_salt: "396/yzq3"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
