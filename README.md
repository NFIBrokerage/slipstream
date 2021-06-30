# Slipstream
![CI](https://github.com/NFIBrokerage/slipstream/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/slipstream/badge.svg)](https://coveralls.io/github/NFIBrokerage/slipstream)
[![hex.pm version](https://img.shields.io/hexpm/v/slipstream.svg)](https://hex.pm/packages/slipstream)
[![hex.pm license](https://img.shields.io/hexpm/l/slipstream.svg)](https://github.com/NFIBrokerage/slipstream/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/NFIBrokerage/slipstream.svg)](https://github.com/NFIBrokerage/slipstream/commits/main)

A slick websocket client for Phoenix channels

See the [online documentation](https://hexdocs.pm/slipstream)

## Main Features

- backed by `:gun` instead of `:websocket_client` (see [why](https://hexdocs.pm/slipstream/why_gun.html#content))
- an `await_*` interface for a interacting [synchronously](https://hexdocs.pm/slipstream/Slipstream.html#module-synchronicity)
- built-in [re-connect and re-join mechanisms](https://hexdocs.pm/slipstream/Slipstream.html#module-retry-mechanisms) matching `phoenix.js`
- a [testing framework](https://hexdocs.pm/slipstream/Slipstream.SocketTest.html#content) for clients
- emits [`:telemetry` events](https://hexdocs.pm/slipstream/telemetry.html#content)

## Installation

Add slipstream to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:slipstream, "~> 0.5"}
  ]
end
```

> N.B.: Slipstream is still being evaluated and tested in production. Once the
> interface is stable and initial bugs worked out, a v1.0.0 version will be
> published.

## Documentation

Documentation is automatically published to
[hexdocs.pm](https://hexdocs.pm/slipstream) on release. You may build the
documentation locally with

```
MIX_ENV=docs mix docs
```

## Contributing

Issues and PRs are always welcome! See our organization
[`CONTRIBUTING.md`](https://github.com/NFIBrokerage/.github/blob/main/CONTRIBUTING.md)
for more information about best-practices and passing CI.

If you're considering sending a PR or otherwise forking Slipstream, you may
wish to read [the implementation docs](guides/implementation.md) first.

## Merge-styles

Incoming PRs will be squashed in order to maintain a more readable commit log.
If you'd like your PR to _not_ be squashed, please say so in your PR
description.

PRs which create examples
(e.g. [#17](https://github.com/NFIBrokerage/slipstream/pull/17)) will
_not_ be squashed so that the commits may be referenced in the tutorial
section of the example (and not have GitHub's ~annoying~ helpful "This
commit does not belong to any branch on this repository..." message, e.g.
[`db79a32`](https://github.com/NFIBrokerage/slipstream/commit/db79a322e4b87ce4390fdb371076dcdbfb776ceb))
