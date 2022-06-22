import Config

config :phoenix, json_library: Jason

if Mix.env() in [:test, :dev] do
  import_config "#{Mix.env()}.exs"
end
