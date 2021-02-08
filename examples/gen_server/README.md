# GenServer Capabilities

Slipstream's callbacks are a superset of `GenServer`, and in fact each
module-based Slipstream socket client _is_ a `GenServer`. The `GenServer`
abstraction provides a simple but powerful interface for message sending
and internal state in a system with many actors.

## Tutorial

In this tutorial, we'll cover the basics of GenServer operations with
Slipstream clients: `GenServer.cast/2`, `GenServer.call/3`, and sending
messages via `Kernel.send/2`.

Let's begin with a fresh client

```elixir
defmodule MyApp.GenServerClient do
  use Slipstream
end
```

## Bonus

As an added bonus, we'll discuss the feature of continues and how to use
`c:Slipstream.handle_continue/2` to schedule a block of work to come next.
