# Slipstream ![CI](https://github.com/NFIBrokerage/slipstream/workflows/Actions%20CI/badge.svg) [![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/slipstream/badge.svg)](https://coveralls.io/github/NFIBrokerage/slipstream)

A slick websocket client for Phoenix channels

See the [online documentation](https://hexdocs.pm/slipstream)

## Installation

Add slipstream to you dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:slipstream, "~> 0.1"}
  ]
end
```

> N.B.: Slipstream is still being evaluated and tested in production. Once the
> interface is stable and initial bugs worked out, a v1.0.0 version will be
> published.

## Contributing

Issues and PRs are always welcome! See our organization
[`CONTRIBUTING.md`](https://github.com/NFIBrokerage/.github/blob/main/CONTRIBUTING.md)
for more information about best-practices and passing CI.

If you're considering sending a PR or otherwise forking Slipstream, you may
wish to read [the implementation docs](guides/implementation.md) first.
