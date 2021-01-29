use Mix.Config

if Mix.env() == :test do
  import_config "../test/support/config/config.exs"
end
