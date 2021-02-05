# Slipstream
![CI](https://github.com/NFIBrokerage/slipstream/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/slipstream/badge.svg)](https://coveralls.io/github/NFIBrokerage/slipstream)
[![hex.pm version](https://img.shields.io/hexpm/v/slipstream.svg)](https://hex.pm/packages/slipstream)
[![hex.pm license](https://img.shields.io/hexpm/l/slipstream.svg)](https://github.com/NFIBrokerage/slipstream/blob/master/LICENSE)

A slick websocket client for Phoenix channels

See the [online documentation](https://hexdocs.pm/slipstream)

## Main Features

- backed by `:gun` instead of `:websocket_client` (see [why](https://hexdocs.pm/slipstream/why_gun.html#content))
- an `await_*` interface for a interacting [synchronously](https://hexdocs.pm/slipstream/Slipstream.html#module-synchronicity)
- built-in [re-connect and re-join mechanisms](https://hexdocs.pm/slipstream/Slipstream.html#module-retry-mechanisms) matching `phoenix.js`
- a [testing framework](https://hexdocs.pm/slipstream/Slipstream.SocketTest.html#content) for clients
- emits [`:telemetry` events](https://hexdocs.pm/slipstream/telemetry.html#content)

## Installation

Add slipstream to you dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:slipstream, "~> 0.4"}
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
