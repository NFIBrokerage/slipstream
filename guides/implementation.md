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

The connection process is spawned and killed upon `Slipstream.connect/2` and
`Slipstream.disconnect/1`, respectively. It directly interfaces with `:gun` in
active mode, meaning that messages from `:gun` connections and requests are
forwarded to the mailbox of the connection process.

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
patterns. This allows one two both produce and match on a data structure
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
