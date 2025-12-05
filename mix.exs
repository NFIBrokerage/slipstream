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
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      package: package(),
      description: description(),
      source_url: "https://github.com/NFIBrokerage/slipstream",
      name: "Slipstream",
      docs: docs(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        inch: :dev,
        bless: :test,
        test: :test,
        dialyzer: :test,
        docs: :docs
      ]
    ]
  end

  defp elixirc_paths(env) when env in [:test, :dev],
    do: ["lib", "test/support", "test/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Slipstream.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mint_web_socket, "~> 1.0 or ~> 0.2"},
      {:telemetry, "~> 1.0 or ~> 0.4"},
      {:jason, "~> 1.0", optional: true},
      {:nimble_options, "~> 1.0 or ~> 0.1"},
      # docs
      {:ex_doc, ">= 0.0.0", only: [:docs], runtime: false},
      {:inch_ex, "== 2.1.0-rc.1", only: [:docs]},
      # test
      {:phoenix, "~> 1.8", only: [:dev, :test, :docs]},
      {:phoenix_view, "~> 2.0", only: [:dev, :test, :docs]},
      {:cowlib, "~> 2.9", override: true, only: [:dev, :test]},
      {:phoenix_pubsub, "~> 2.0", override: true, only: [:docs, :dev, :test]},
      {:plug_cowboy, "~> 2.0", only: [:dev, :test]},
      {:mox, "~> 1.0", only: [:dev, :test]},
      {:credo, "~> 1.5", only: :test},
      {:bless, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.7", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test, :docs], runtime: false}
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
        "guides/telemetry.md",
        "guides/implementation.md",
        "examples/README.md": [filename: "examples", title: "Examples"],
        "examples/graceful_startup/README.md": [
          filename: "graceful_startup_example",
          title: "Graceful Startup"
        ],
        "examples/repeater/README.md": [
          filename: "repeater_example",
          title: "Repeater-style Client"
        ],
        "examples/rejoin_on_reconnect/README.md": [
          filename: "rejoin_on_reconnect_example",
          title: "Rejoin on Reconnect"
        ],
        "examples/gen_server/README.md": [
          filename: "gen_server_example",
          title: "GenServer Capabilities"
        ],
        "examples/scripting/README.md": [
          filename: "scripting_example",
          title: "Scripting"
        ]
      ],
      groups_for_extras: [
        Guides: ["examples/README.md" | Path.wildcard("guides/*.md")],
        Examples: Path.wildcard("examples/*/README.md")
      ],
      groups_for_modules: [
        Testing: [
          Slipstream.SocketTest
        ]
      ],
      groups_for_functions: [
        "Synchronous Functions": &(&1[:synchronicity] == :synchronous)
      ],
      skip_undefined_reference_warnings_on: [
        "guides/implementation.md",
        "guides/telemetry.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
