# Slipstream

![CI](https://github.com/NFIBrokerage/slipstream/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/slipstream/badge.svg)](https://coveralls.io/github/NFIBrokerage/slipstream)
[![hex.pm version](https://img.shields.io/hexpm/v/slipstream.svg)](https://hex.pm/packages/slipstream)
[![hex.pm license](https://img.shields.io/hexpm/l/slipstream.svg)](https://github.com/NFIBrokerage/slipstream/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/NFIBrokerage/slipstream.svg)](https://github.com/NFIBrokerage/slipstream/commits/main)

A slick websocket client for Phoenix channels

See the [online documentation](https://hexdocs.pm/slipstream)

## Main Features

- backed by [Mint.WebSocket](https://github.com/NFIBrokerage/mint_web_socket)
- an `await_*` interface for a interacting [synchronously](https://hexdocs.pm/slipstream/Slipstream.html#module-synchronicity)
- built-in [re-connect and re-join mechanisms](https://hexdocs.pm/slipstream/Slipstream.html#module-retry-mechanisms) matching `phoenix.js`
- a [testing framework](https://hexdocs.pm/slipstream/Slipstream.SocketTest.html#content) for clients
- emits [`:telemetry` events](https://hexdocs.pm/slipstream/telemetry.html#content)

## Installation

Add slipstream to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:slipstream, "~> 1.0"}
  ]
end
```

## Documentation

Documentation is automatically published to
[hexdocs.pm](https://hexdocs.pm/slipstream) on release. You may build the
documentation locally with

```
MIX_ENV=docs mix docs
```

## Contributing

Issues and PRs are very welcome! See our organization
[`CONTRIBUTING.md`](https://github.com/NFIBrokerage/.github/blob/main/CONTRIBUTING.md)
for more information about best-practices and passing CI.

If you're considering sending a PR or otherwise forking Slipstream, you may
wish to read [the implementation docs](guides/implementation.md) first.
