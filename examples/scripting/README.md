# Scripting


Sometimes, it's really nice to safely play and experiment in your local development environment. 

In this tutorial we'll cover how to use the synchronous `await_*` family of
functions to write scripts for interacting with `Phoenix.Channel`s in an
IEx session or in a `mix run script.exs` script. In this tutorial, unlike
others, we simply walk through a script from top to bottom, as opposed to
modifying an existing client.

For the sake of ease of development and for you, the reader, this repository
runs a phoenix server with a socket endpoint on `localhost:4000` in dev-mode.

To prepare for this tutorial, clone the
[`NFIBrokerage/slipstream`](https://github.com/NFIBrokerage) repository,
install the necessary Elixir and Erlang versions with `asdf install` (see more
about [asdf](https://github.com/asdf-vm/asdf-elixir)). Then start an IEx server
with `MIX_ENV=dev iex -S mix`. The `.iex.exs` script in the root of this
repository will start the phoenix endpoint on `localhost:4000` as the IEx
session begins.

```console
$ iex -S mix
Erlang/OTP 23 [erts-11.1] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Interactive Elixir (1.11.2) - press Ctrl+C to exit (type h() ENTER for help)
20:13:38.963 [info] Running SlipstreamWeb.Endpoint with cowboy 2.8.0 at 0.0.0.0:4000 (http)
20:13:38.967 [info] Access SlipstreamWeb.Endpoint at http://localhost:4000
iex(1)>
```

## Tutorial

To begin, let's import some functions from Slipstream that we'll use to
establish and interact with our connection.

```elixir
iex> import Slipstream
iex> import Slipstream.Socket
```

The `Slipstream` module defines most of the functions we'll use to open and
interact with a connection while `Slipstream.Socket` provides helper functions
to interact with our `socket` (a `t:Slipstream.Socket.t/0`).

Let's connect!

```elixir
iex> socket = connect!(uri: "ws://localhost:4000/socket/websocket") |> await_connect!
#Slipstream.Socket<assigns: %{}, ...>
```

We connect to the _websocket_ endpoint for `SlipstreamWeb.Endpoint`.
The endpoint has a `socket/3` definition like so:

```elixir
socket("/socket", SlipstreamWeb.UserSocket,
  websocket: true,
  longpoll: false
)
```

Meaning that we can find the websocket endpoint at `/socket/websocket`. Note
also that we've changed the _scheme_ of the URI from `http` to `ws`.

Upon connection we should also see a logger message from the
`SlipstreamWeb.Endpoint` saying that a client has connected to the socket.

```text
20:20:59.874 [info] CONNECTED TO SlipstreamWeb.UserSocket in 60µs
  Transport: :websocket
  Serializer: Phoenix.Socket.V2.JSONSerializer
  Parameters: %{"vsn" => "2.0.0"}
```

But why do we need `await_connect!/1` in this scenario? The `connect/2`,
`join/3`, `leave/2`, etc. functions are asynchronous requests to connect,
join, and leave, respectively. The `await_*` functions synchronously block
until the responses to those requests are received.

Now that we're connected, let's join a topic! `SlipstreamWeb.UserSocket`
defines a channel on the `"rooms:lobby"` topic like so

```elixir
channel("rooms:lobby", SlipstreamWeb.InteractiveChannel)
```

So lets connect to that:

```elixir
iex> topic = "rooms:lobby"
iex> socket = join(socket, topic, %{"fizz" => "buzz"}) |> await_join!(topic)
#Slipstream.Socket<assigns: %{}, ...>
```

And we should see a message from the endpoint about the join:

```
20:38:35.208 [info] JOINED rooms:lobby in 16µs
  Parameters: %{"fizz" => "buzz"}
```

And now let's push a message to a `c:Phoenix.Channel.handle_in/3` written like
so

```elixir
# just swallows the request
def handle_in("quicksand", _params, socket) do
  {:noreply, socket}
end
```

```elixir
iex> push!(socket, topic, "quicksand", %{"a" => "b"})
"2"
```

Why no `await_push` function for `push!/4`? And what's with the `"2"` as the
return? `push!/4` (and `push/5`) are a bit different from the other functions.
Pushes are completely asynchronous as the `Phoenix.Channel` does not have to
reply to any push. The `"2"` that got returned can be used to find replies,
however.

Let's push to a `c:Phoenix.Channel.handle_in/3` clause that _does_ reply

```elixir
# responds to the request
def handle_in("ping", _params, socket) do
  {:reply, {:ok, %{"pong" => "pong"}}, socket}
end
```

```elixir
iex> push!(socket, topic, "ping", %{}) |> await_reply!()
{:ok, %{"ping" => "pong"}}
```

Now we're using `await_reply!/1`, a function that synchronously waits for a
push to receive a reply. But how does it know which push it is waiting for?
The `"2"` returned in the above `push!/4` example is what is called in the
implementation of Slipstream a "ref." Refs are passed between the client and
server to signify which message a reply is referencing. E.g. if a join request
sends a ref of `"1"`, the `Phoenix.Channel` will write a reply to that ref
telling the client whether or not the join has been accepted. `await_reply!/1`
uses the ref returned from `push!/4` to find the reply to that push.

Now we've pushed a message and seen a reply to a push, but what about receiving
a message that isn't a reply?

```elixir
# responds, but not with a reply
# just an async send
def handle_in("push to me", _params, socket) do
  push(socket, "foo", %{"bar" => "baz"})

  {:noreply, socket}
end
```

This `c:Phoenix.Channel.handle_in/3` clause will trigger a
`Phoenix.Channel.push/3` to our client. In a module-based client, we would
typically handle this with `c:Slipstream.handle_message/4`, but how can we
await these messages in a script?

Let push a message to this `handle_in`

```elixir
iex> push!(socket, topic, "push to me", %{})
iex> flush
{:__slipstream_event__,
 %Slipstream.Events.MessageReceived{
   event: "foo",
   payload: %{"bar" => "baz"},
   topic: "rooms:lobby"
 }}
```

We can see that the IEx process receives a message when we `flush/0`. We can
await and decode this message into a more digestible format with the
`Slipstream.await_message!/4` macro. This macro takes patterns as its arguments
for the topic, event, and payload, so we can selectively match messages with
match patterns.

```elixir
iex> push!(socket, topic, "push to me", %{})
iex> await_message!(^topic, "foo", %{"bar" => "baz"})
{"rooms:lobby", "foo", %{"bar" => "baz"}}
```

But do we need to know the exact message we're awaiting ahead of time? No, we
can match all incoming messages like so

```elixir
iex> push!(socket, topic, "push to me", %{})
iex> await_message!(_, _, _)
{"rooms:lobby", "foo", %{"bar" => "baz"}}
```

Finally, let's leave the topic and disconnect, cleaning up our connection
cleanly.

```elixir
iex> socket = leave(socket, topic) |> await_leave!(topic)
#Slipstream.Socket<assigns: %{}, ...>
iex> socket |> disconnect() |> await_disconnect!
#Slipstream.Socket<assigns: %{}, ...>
```
