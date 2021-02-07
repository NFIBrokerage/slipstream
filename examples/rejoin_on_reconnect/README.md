# Rejoin on Reconnect

Slipstream provides `rejoin/3` and `reconnect/1` to provide out-of-the-box
retry mechanisms for re-establishing a client's functions after network
outages.

For clients that

- use the default implementation of `c:Slipstream.handle_disconnect/2`
- call `Slipstream.connect/2` or `Slipstream.connect!/2` in
  `c:Slipstream.init/1`
- and call `Slipstream.join/3` in `c:Slipstream.handle_connect/1`

These retry mechanisms work without any extra effort. But for clients which
dynamically join topics, you will have to take re-joins into account after a
disconnect, since that third condition about `Slipstream.join/3`ing may not
be true.

Consider a client written like so:

```elixir
defmodule MyClient do
  use Slipstream

  def join(topic) do
    GenServer.cast(__MODULE__, {:join, topic})
  end

  def start_link(config) do
    Slipstream.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl Slipstream
  def init(config) do
    {:ok, connect!(config)}
  end

  @impl Slipstream
  def handle_cast({:join, topic}, socket) do
    {:noreply, join(socket, topic)}
  end
end
```

This client uses the default implementation of
`c:Slipstream.handle_disconnect/2`, but does not join any topics in its
`c:Slipstream.handle_connect/1` callback (since it uses the default
implementation). It doesn't know the topics it wishes to join ahead of time,
so we say that this client joins topics _dynamically_.

Dynamic clients like this one will not automatically re-join after a
disconnect (however they will re-connect automatically due to the usage of the
default `c:Slipstream.handle_disconnect/2` callback).

## Tutorial

In this tutorial, we will start with the above client and refactor it so that
it will gracefully re-join all topics when it reconnects after a disconnect.

We will start by modifying the `c:Slipstream.init/1` callback to store a list
of topics in the socket assigns using `Slipstream.Socket.assign/3`
([`2b0bd58`](https://github.com/NFIBrokerage/slipstream/commit/2b0bd582ff99d294274a323d8a902e101226c3be))

```elixir
@impl Slipstream
def init(config) do
  socket =
    config
    |> connect!()
    |> assign(:topics, [])
    
  {:ok, socket}
end
```

And every time the client is told to join a topic with `MyClient.join/1`, we
want to update that `socket.assigns.topics` key to store the new topic. We
do that in the `c:Slipstream.handle_cast/2` callback with
`Slipstream.Socket.update/3`
([`70e802f`](https://github.com/NFIBrokerage/slipstream/pull/22/commits/70e802f7710a46d889939325ba7d62a680b60a96))

```elixir
@impl Slipstream
def handle_cast({:join, new_topic}, socket) do
  socket =
    socket
    |> update(:topics, fn existing_topics -> [new_topic | existing_topics] end)
    |> join(new_topic)

  {:noreply, socket}
end
```

So now we have in `socket.assigns.topics` a list of all topics that we have
attempted to join. (Curious how to store only the topics we have _successfully_
joined? That is left as an exercise to the reader, with the solution written as
an HTML comment at the bottom of this file.)

Now we must implement a mechanism to re-join after a disconnect. More
accurately, we must implement a mechanism to re-join after a re-connection.
When a client is re-connected after a disconnect, the
`c:Slipstream.handle_connect/1` callback is invoked again (it is first
invoked upon the first successful connection to the remote websocket server).
That's the perfect place to put our re-join mechanism
([`70e802f`](https://github.com/NFIBrokerage/slipstream/pull/22/commits/70e802f7710a46d889939325ba7d62a680b60a96))

```elixir
@impl Slipstream
def handle_connect(socket) do
  socket =
    socket.assigns.topics
    |> Enum.reduce(socket, fn topic, socket ->
      case rejoin(socket, topic) do
        {:ok, socket} -> socket
        {:error, _reason} -> socket
      end
    end)

  {:ok, socket}
end
```

Whenever we connect, be it the first connect or a re-connection, we will
attempt to `Slipstream.rejoin/3` all the topics in `socket.assigns.topic`.
On the initial connect this list is empty, so we keep the dynamic nature of
only joining topics on request (via `GenServer.cast/2`).

Think that this should be the default behavior of a reconnection? Advocate for
this feature being built-in behavior in
[#18](https://github.com/NFIBrokerage/slipstream/issues/18).

<!--

In order to store only the topics we have _successfully_ joined, we simply
move the call to `Slipstream.Socket.update/3` into the
`c:Slipstream.handle_join/3` callback implementation, defining it if it does
not yet exist. That callback is only invoked on a successful topic join, so
adding the topic to the `socket.assigns.topics` list then will ensure that
only successfully-joined topics make their way into that key.

-->
