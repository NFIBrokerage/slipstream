# Slipstream ![CI](https://github.com/NFIBrokerage/slipstream/workflows/Actions%20CI/badge.svg)

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

## Contributing

Issues and PRs are welcome! If you're considering sending a PR or
otherwise forking Slipstream, you may wish to read [the implementation
docs](guides/implementation.md) first.

#### Code coverage

[NFIBrokerage](https://github.com/NFIBrokerage) shoots for 100% coverage (via
[`:excoveralls`](https://github.com/parroty/excoveralls)), but we always allow
ignoring lines or blocks of code that would either be impractical to test
or would consume too much of your time to do so (your time is valuable :).
In those cases, we strongly prefer using comment-style ignores, like so:

```elixir
# N.B.: to get coverage on this block, we'd have to brutally kill the HTTP
# server, which we need to be running for other tests to pass
# coveralls-ignore-start
def handle_event(%ServerDisconnect{}, state) do
  {:stop, {:shutdown, :disconnected}, state}
end

# coveralls-ignore-stop
```

With a helpful comment explaining why this case is too tough to test. Coveralls
also allows ignoring by adding file patterns to the `coveralls.json` file:

```json
{
  "coverage_options": {
    "minimum_coverage": 100,
    "treat_no_relevant_lines_as_covered" : true
  },
  "skip_files": [
    "^test",
    "^deps"
  ]
}
```

But in our experience, this only leads to confusion over why a file is not
being reported in the coverage detail. If an entire module needs to be ignored,
we prefer wrapping the entire `defmodule/2` call in ignore comments.

#### Formatting

We use the Elixir formatter introduced in Elixir 1.6 in check-mode as part
of the CI. Some editors have supported formatting before _the_ formatter was
introduced, and ignore configuration or differ in their methods of formatting.
In particular, we set our line-length option to 80 columns and make sparing
use of the `locals_without_parens` option, which some formatting extensions
ignore. A simple run of `mix format` on the command line before committing
is always wise.

#### Linting

We use two tools for linting: `mix compile --warnings-as-errors` and
[`credo`](https://github.com/rrrene/credo). Either of these checks failing to
pass will fail the CI, even for test files.

#### Bless

To pull all of these checks together for development, we publish a
[`bless`](https://github.com/NFIBrokerage/bless) library which runs all commands
in serial and fails if any check fails. A successful run of

```
$ mix bless
```

before committing usually translates into a green check mark from the CI.
If you cannot get a good bless run, submit the PR anyways! We'll be happy to
help you get that green check mark.
