# Repeater-style Client

We call any client that repeats messages from another service's endpoint a
_repeater_ client.

This is a useful pattern when one wishes to ferry messages (without
changing them) from one `Phoenix.Endpoint` to another when the services
are different, or when the services are the same but endpoint clustering is
not possible or desired.

In order to make this happen, we will create a client that

- connects to the remove service
- subscribes to the topic we wish to repeat
- broadcasts messages as they happen to this service's endpoint

## Tutorial

We start with an empty client
([`db79a32`](https://github.com/NFIBrokerage/slipstream/commit/db79a322e4b87ce4390fdb371076dcdbfb776ceb))

```elixir
defmodule MyApp.RepeaterClient do
  @moduledoc """
  A repeater-kind of client which re-broadcasts messages from another service
  into this service's endpoint
  """

  use Slipstream

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config), do: {:ok, connect!(config)}
end
```

This client is pretty standard. It receives configuration from its supervisor,
so it could be started in a `lib/my_app/application.ex` file with something
like:

```elixir
def MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {MyApp.RepeaterClient, uri: "ws://service-b.local:4000/socket/websocket"},
      MyAppWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

First thing's first, let's make sure we join our desired topic upon connection
by adding a `c:Slipstream.handle_connect/1` implementation that calls
`Slipstream.join/3`
([`37b392e`](https://github.com/NFIBrokerage/slipstream/commit/37b392e823457f9542614da724cbf0c9e0181b73))

```elixir
@topic "rooms:lobby"

@impl Slipstream
def handle_connect(socket), do: {:ok, join(socket, @topic)}
```

And let's add an empty implementation of `c:Slipstream.handle_message/4`
([`3855594`](https://github.com/NFIBrokerage/slipstream/commit/38555946dfa583dc100084901e6a24e5467766da))

```elixir
@impl Slipstream
def handle_message(topic, event, payload, socket) do
  {:ok, socket}
end
```

`c:Slipstream.handle_message/4` is invoked whenever the remote server
performs a `Phoenix.Channel.push/3`, or whenever the topic to which the
client is subscribed receives a broadcast. Broadcasts are sent to all
subscribers of a topic without a `Phoenix.Channel` explicitly needing to use
`Phoenix.Channel.push/3`, but the interface is the same for Slipstream clients:
`c:Slipstream.handle_message/4` will be invoked with the broadcast.

Now for the "repeater" part, we will publish these broadcasts or pushes onto
our service's endpoint using `c:Phoenix.Endpoint.broadcast/3`
([`01b5568`](https://github.com/NFIBrokerage/slipstream/commit/01b55688084b862fbe33df44dd66567766005835))

```elixir
@endpoint SlipstreamWeb.Endpoint

@impl Slipstream
def handle_message(topic, event, payload, socket) do
  @endpoint.broadcast(topic, event, payload)

  {:ok, socket}
end
```

And that's all! Each `Phoenix.Channel.push/3` or
`c:Phoenix.Endpoint.broadcast/3` published on the topic will be (re)broadcasted
on the endpoint in the service of the repeater. See
[`examples/repeater/client.ex`](https://github.com/NFIBrokerage/slipstream/blob/main/examples/repeater/client.ex)
for the full code of this example client and a small test case at
[`test/slipstream/examples/repeater_test.exs`](https://github.com/NFIBrokerage/slipstream/blob/main/test/slipstream/examples/repeater_test.exs).
