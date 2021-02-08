use Mix.Config

if Mix.env() in [:test, :dev] do
  import_config "#{Mix.env()}.exs"
end
