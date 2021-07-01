# Implementation

Slipstream has some implementation decisions that may appear strange or
overly-complicated on the surface. My opinion is that these help not only with
usability but also test-ability. The test suite is rather compact: it covers
a great many cases for the small number of lines in which it is implemented.

The primary design decisions that enable this easy workflow are the hard
boundary between the client and connection processes and the disambiguation
of messages into events and commands:

## Process Architecture

Slipstream starts two processes to run a websocket connection:

- the client process (modules with `use Slipstream`)
- the connection process

The connection process is spawned and killed upon `Slipstream.connect/2`
and `Slipstream.disconnect/1`, respectively. It directly interfaces with
the WebSocket connection via `Mint.WebSocket`.

The client process is simply a GenServer that has `c:GenServer.handle_info/2`
clauses injected to handle slipstream events. The entire purpose of the client
process is to provide a clean-feeling interface to the connection process. One
_could_ (but is not recommended to-) forego the client process and deal with
websockets synchronously with the `Slipstream.await_*` family of functions.

## Events and Commands

Slipstream separates out messages into two categories: events
and commands. To some extent, Slipstream follows the [Event
Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) and [Command
Pattern](https://en.wikipedia.org/wiki/Command_pattern) design patterns with
this choice.

One might think to implement the communication between the [connection and
client processes](#process-architecture) by using data structures like
`%Message{}` and `%Reply{}` and `%Heartbeat{}`, but it's not exactly clear
who should send which message to whom. Should the connection process be sending
`%Message{}` to the server, or vice-versa? Could we re-use that data structure
for both directions?

Slipstream's `Slipstream.Events` and `Slipstream.Commands` data structures
keep this boundary clear. The client process sends commands to the connection
process when it seeks to change the connection state (join/leave) or push
a message. The connection process notifies the client of its status and how
the connection changes (whenever it changes meaningfully), with events. Events
declare how the connection has changed, which informs the client process of how
it should change the state of the `t:Slipstream.Socket.t/0` as the connection
evolves.

Events are written in the past tense in the form of `NounVerbed`, as in
`ThingHappened`, while commands are written in the form of `VerbNoun`, as in
`DoThing`.

### Signatures

Events arrive from the connection process in the format of

```elixir
{:__slipstream_event__, event_struct}
```

where `event_struct` is any struct from `Slipstream.Events`. And commands are
sent to the connection process in the form of:

```elixir
{:__slipstream_command__, command_struct}
```

The `Slipstream.Signatures` file defines two macros that wrap the above
patterns. This allows one to both produce and match on a data structure
and have confidence that the resulting data structure or match pattern will
be an event or command.

This pattern is not very revolutionary: it's really just an extension of DRY
into match patterns. It keeps the matches and routing functions clear of dirty
implementation details like 'exactly how the data structures are wrapped.'

For example, a `HeartbeatAcknowledged` event can be produced like so:

```elixir
alias Slipstream.Events
import Slipstream.Signatures, only: [event: 1]

event(%Events.HeartbeatAcknowledged{})
#=> {:__slipstream_event__, %Slipstream.Events.HeartbeatAcknowledged{}}
```

And then later-on this data structure can be matched with any sort of
clause like so:

```elixir
alias Slipstream.Events
import Slipstream.Signatures, only: [event: 1]

maybe_event = event(%Events.HeartbeatAcknowledged{})

case maybe_event do
  event(%Events.HeartbeatAcknowledged{} = event) -> {:ok, event}
  _ -> :error
end
#=> {:ok, %Events.HeartbeatAcknowledged{}}
```

Since the client and connection process communicate with each other though
message sending and `GenServer.call/3`, these signature macros keep the
messages recognizable and enforce the communication boundary.

I dub this pattern the "signature pattern" (but realize that I am probably
not the first to discover it).

## The Token Pattern

The `t:Slipstream.Socket.t/0` data structure is built to closely resemble the
`t:Phoenix.Socket.t/0` structure, and feel similar in usage. These are both
implementations of a pattern coined by [`@rrrene`](https://github.com/rrrene):
the [token pattern](https://rrrene.org/2018/05/14/flow-elixir-designing-apis/).

The idea is fairly straight-forward: instead of passing around only the values
each function needs, you pass around a structure which contains all information
available and provide a functional API to modify the internals (by producing a
new structure). These structures are called "tokens."

The token pattern is particularly useful for writing flexible pipelines. E.g.
a piece of code that does something like this:

```elixir
def do_work(request) do
  request
  |> decode_request()
  |> hydrate_request_with_background_info()
  |> start_computation_measurements()
  |> do_the_computation()
  |> end_computation_measurements()
  |> send_the_result_somewhere()
end
```

These functions are all chained together, so it may seem perfectly appropriate
to write the functions in a way that each consumes the direct output of the
preceding function in the chain. But if we eventually need another `do_work/1`
clause that handles a different sort of request and say, cuts out the
`hydrate_request_with_background_info/1` step, we will likely have to refactor
at least a few of the functions to properly emit and consume the data they need.

Instead of taking and giving _only_ the information each function needs, each
function should pass along a token structure containing all the information in
the request:

```elixir
def do_work(request) do
  %Token{initial_request: request}
  |> decode_request() # returns a new %Token{}
  |> hydrate_request_with_background_info() # returns a new %Token{}
  ..
end
```

If we need to cut out or add new functions to the pipeline, we are less likely
to need to refactor any of the component functions.

The usage of sockets in Slipstream is not so chain-y as the example, but the
socket token allows a clean API of functions that each take a socket and
some other information and emit a new socket token.

```elixir
@impl Slipstream
def handle_info({:join, topic}, socket) do
  socket =
    if connected?(socket) and not joined?(socket, topic) do
      join(socket, topic)
    else
      socket
    end

  {:noreply, socket}
end
```
