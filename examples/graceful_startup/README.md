# Graceful Startup

A client that gracefully handles errors in configuration at start-up time.

As the documentation for `c:GenServer.init/1` details, a GenServer may return
`:ignore` instead of `{:ok, initial_state}` in its `c:GenServer.init/1`
callback. This will cause the client to

> exit normally without entering the loop or calling `c:GenServer.terminate/2`.
> If used when part of a supervision tree the parent supervisor will not
> fail to start nor immediately try to restart the `GenServer`.

This makes it a good option for handling failures to start the client.
`c:Slipstream.init/1` is mostly a wrapper around `c:GenServer.init/1`, so we
may return `:ignore` and see the same behavior.

## Tutorial

We start with an empty client module: `c5a08fdcdb02bfe8721b4814f18e495942452426`

```elixir
defmodule MyApp.GracefulStartupClient do
end
```

And immediately fill out the Slipstream basics like a `start_link/1`
implementation (so the module may be supervised), and an invocation of
`use Slipstream`: `8d44dd057f6729b3d34787b85a57f0a968120946`

```elixir
defmodule MyApp.GracefulStartupClient do
  use Slipstream

  @moduledoc "..."

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
```

Then we add a basic implementation of the `c:Slipstream.init/1` callback:
`a51e77c70b06086fe0ce5673d6650c0950cf30d8`

```elixir
@impl Slipstream
def init(_args) do
  config = Application.fetch_env!(:my_app, __MODULE__)
  {:ok, connect!(config)}
end
```

But note that this introduces two potential `raise`ing errors in our
`c:Slipstream.init/1` callback:

1. `Application.fetch_env!/2` will raise of the key-value pair is not defined
   in configuration (`config/*.exs`)
2. `Slipstream.connect!/2` will raise if the configuration passed as the first
   argument is not valid according to `Slipstream.Configuration`.

And also note that a `raise` in an `c:Slipstream.init/1` callback will fail
the start-up of the supervisor process. If this client is started in the
Application supervision tree (`lib/my_app/application.ex`), it will take
down the entire application on error.

So let's refactor this to make it a bit more safe! First, we switch
`Application.fetch_env!/2` to its more graceful counterpart:
`Application.fetch_env/2`, which returns `{:ok, config}` when
the configuration is defined and `:error` when it is not:
`90ceb4a5947b8e78c1ab9a1abfe4c6a55b1ab689`

```elixir
@impl Slipstream
def init(_args) do
  with {:ok, config} <- Application.fetch_env(:slipstream, __MODULE__) do
    {:ok, connect!(config)}
  else
    :error -> :ignore
  end
end
```

So now the client will attempt to connect only if the configuration
is defined. But it can still fail, as we use the raising
`Slipstream.connect!/2`.  We refactor that to `Slipstream.connect/2` in
`b3be44525acfb6cda828a80d15e28d3351852540`:

```elixir
@impl Slipstream
def init(_args) do
  with {:ok, config} <- Application.fetch_env(:slipstream, __MODULE__),
       {:ok, socket} <- connect(config) do
    {:ok, socket}
  else
    :error -> :ignore
    {:error, _reason} -> :ignore
  end
end
```

So now in either of our failure-cases, the client will simply not start-up
instead of potentially crashing the entire application. This is an application
of _graceful degradation_: in cases of system failure, we degrade our
performance instead of entirely giving up.

In this example, we go on to add helpful `Logger`
messages that declare when a failure case has been met:
`09d1a83311b039d2dcd743a2a54cbba4287a21d2`. To see the full example code,
open up `examples/graceful_startup/client.ex`. A small test suite can be
found at `test/slipstream/examples/graceful_startup_test.exs`.
