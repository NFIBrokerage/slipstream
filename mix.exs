defmodule Slipstream.MixProject do
  use Mix.Project

  @source_url "https://github.com/NFIBrokerage/slipstream"
  @version_file Path.join(__DIR__, ".version")
  @external_resource @version_file
  @version (case Regex.run(~r/^v([\d\.\w-]+)/, File.read!(@version_file),
                   capture: :all_but_first
                 ) do
              [version] -> version
              nil -> "0.0.0"
            end)

  def project do
    [
      app: :slipstream,
      version: @version,
      # Slipstream makes use of the `@derive {Inspect, ..` feature introduced
      # in elixir 1.8, but it only uses the feature if it detects that the
      # current elixir version meets the requirements.
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: extra_compilers(Mix.env()) ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        credo: :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        inch: :dev,
        bless: :test,
        test: :test
      ],
      test_coverage: [tool: ExCoveralls],
      package: package(),
      description: description(),
      source_url: "https://github.com/NFIBrokerage/slipstream",
      name: "Slipstream",
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_compilers(env) when env in [:test], do: [:phoenix]
  defp extra_compilers(_), do: []

  def application do
    [
      mod: {Slipstream.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gun, "~> 1.0"},
      {:phoenix, "~> 1.0"},
      {:telemetry, "~> 0.4"},
      {:jason, "~> 1.0", optional: true},
      {:nimble_options, "~> 0.1"},
      # docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:inch_ex, "== 2.1.0-rc.1", only: [:dev, :test]},
      # test
      {:cowlib, "~> 2.9", override: true, only: [:dev, :test]},
      {:phoenix_pubsub, "~> 2.0", override: true, only: [:dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.5", only: :test},
      {:bless, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.7", only: :test}
    ]
  end

  defp package do
    [
      name: "slipstream",
      files: ~w(lib .formatter.exs mix.exs README.md .version),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp description do
    "A slick websocket client for Phoenix channels"
  end

  defp docs do
    [
      deps: [],
      language: "en",
      formatters: ["html"],
      main: Slipstream,
      extras: [
        "CHANGELOG.md",
        "guides/implementation.md"
      ],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.md")
      ],
      groups_for_modules: [
        Testing: [
          Slipstream.SocketTest
        ]
      ],
      skip_undefined_reference_warnings_on: ["guides/implementation.md"]
    ]
  end
end
