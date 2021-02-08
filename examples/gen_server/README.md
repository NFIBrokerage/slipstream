# GenServer Capabilities

Slipstream's callbacks are effectively a superset of `GenServer`, and in
fact each module-based Slipstream socket client _is_ a `GenServer`. The
`GenServer` abstraction provides a simple but powerful interface for message
sending and internal state in a system with many actors.

## Tutorial

In this tutorial, we'll cover the basics of GenServer operations with
Slipstream clients: `GenServer.cast/2`, `GenServer.call/3`, and sending
messages via `Kernel.send/2`.

If you haven't already acquainted yourself with GenServers and how to supervise
them, see the official Elixir guides:

- [`GenServer`s](https://elixir-lang.org/getting-started/mix-otp/genserver.html)
- [Supervision and `Application`](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html)

Let's begin with a fresh client

```elixir
defmodule MyApp.GenServerClient do
  use Slipstream

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(opts) do
    {:ok, connect!(opts)}
  end
end
```

Already we are taking advantage of `Slipstream.start_link/3` (which is roughly
the same as `GenServer.start_link/3`) and `c:Slipstream.init/1` (which is
roughly the same as `c:GenServer.init/1` except that you must return a
`t:Slipstream.Socket.t/0`).

Let's add a clause for handling `GenServer.cast/2`s
(commit)

```elixir
@impl Slipstream
def handle_cast({:join, topic, params}, socket) do
  {:noreply, join(socket, topic, params)}
end
```

This clause will accept casts telling the client to join a topic and perform
the join within the client's process. Notice how `c:Slipstream.handle_cast/2`
looks exactly the same as `c:GenServer.handle_cast/2`. The two are completely
compatible and all returns accepted by the GenServer callback are accepted by
Slipstream as well.

If one were to ask the client to join a topic, they need only
`GenServer.cast/2` it

```elixir
iex> GenServer.cast(MyApp.GenServerClient, {:join, "rooms:lobby", %{}})
:ok
```

Now let's try an implementation to handle `GenServer.call/3` requests. Calling
is a synchronous action for which the caller will block until a reply is
received. This is the only callback in the set of `Slipstream` callbacks which
can produce a reply-tuple (`{:reply, reply, socket}`). Let's start with
something simple like a ping request
(commit)

```elixir
@impl Slipstream
def handle_call(:ping, _from, socket) do
  {:reply, :pong, socket}
end
```

This example doesn't really do very much. If we call our client with a
`:ping` request, we expect a `:pong` result.

```elixir
iex> GenServer.call(MyApp.GenServerClient, :ping)
:pong
```

Let's try a more interesting `GenServer.call/3` feature: the client replying
asynchronously. Surely the caller blocks while calling `GenServer.call/3`, but
the server which hears the call does not necessarily _have_ to respond in a
blocking fashion. With a combination of a noreply tuple (`{:noreply, socket}`)
and `GenServer.reply/2`, we can provide an API for synchronously requesting a
join
(commit)

```elixir
@impl Slipstream
def handle_call({:join, topic, params}, from, socket) do
  socket =
    socket
    |> assign(:join_request, from)
    |> join(topic, params)

  {:noreply, socket}
end

@impl Slipstream
def handle_join(_topic, response, socket) do
  GenServer.reply(socket.assigns.join_request, {:ok, response})

  {:ok, socket}
end
```

And now we may call from another process

```elixir
iex> GenServer.call(MyApp.GenServerClient, {:join, "rooms:lobby", %{}})
{:ok, %{}}
```

And only receive a reply when the topic has been joined.

Finally, the `c:GenServer.handle_info/2` callback provides a catch-all callback
for handling any messages sent to the server which are not calls or casts.
This callback works asynchronously like `c:GenServer.handle_cast/2`, but can
be triggered by another process performing a `Kernel.send/2` instead of a
`GenServer.cast/2`.

We might write a client which uses `:timer.send_interval/2`,
`Process.send_after/4`, or just plain `Kernel.send/2` to remind itself to do
work later, or another process may wish to send the client a message to
alter its behavior. We'll take the approach of that last suggestion with this
callback implementation for `c:Slipstream.handle_info/2`
(commit)

```elixir
@impl Slipstream
def handle_info(:conclude_subscription, socket) do
  {:stop, :normal, disconnect(socket)}
end
```

And we'll revisit that `use Slipstream` invocation to add

```elixir
use Slipstream, restart: :temporary
```

This will ensure that when we tell the client to clean up and disconnect from
its subscription that it should shutdown and not be restarted.

When the client hears a message `:conclude_subscription`, it will disconnect
gracefully and shut down the `GenServer` process. We can trigger this with

```elixir
iex> MyApp.GenServerClient |> Process.whereis() |> send(:conclude_subscription)
:conclude_subscription
```

## Bonus

As an added bonus, we'll discuss the feature of continues and how to use
`c:Slipstream.handle_continue/2` to schedule a block of work to come next.

Since OTP 21, the `c:GenServer.handle_continue/2` callback has provided a way
to immediately schedule the next block of work without performing a
`send(self(), {:next_work, params})` message.

You may wish to make use of this feature by scheduling the connection request
to occur after `c:Slipstream.init/1`, soas the application supervision tree
may start up quickly, in the case where a client would have to do a large
amount of work before connecting.

```elixir
@impl Slipstream
def init(config) do
  socket = new_socket() |> assign(:config, config)
  {:ok, socket, {:continue, :connect}}
end

@impl Slipstream
def handle_continue(:connect, socket) do
  # do some expensive work...
  {:noreply, connect!(socket, socket.assigns.config)}
end
```

This will make the call to `Slipstream.connect!/2` occur _after_ the conclusion
of the `c:Slipstream.init/1` callback.
