# Design

Slipstream is designed to be as extensible as it is <missing word here>

such and such about concurrency furthering that idea

## Process Architecture

Slipstream starts two processes to run a websocket connection:

- the server process (modules with `use Slipstream`)
- the connection process

The connection process is spawned and killed upon `Slipstream.connect/2` and
`Slipstream.disconnect/1`, respectively. It directly interfaces with `:gun` in
active mode, meaning that messages from `:gun` connections and requests are
forwarded to the mailbox of the connection process.

The server process is simply a GenServer that has `c:GenServer.handle_info/2`
clauses injected to handle slipstream events. The entire purpose of the server
process is to provide a clean-feeling interface to the connection process. One
_could_ (but is not recommended to-) forgoe the server process and deal with
websockets synchronously with the `Slipstream.await_*` family of functions.

Events arrive from the connection process in the format

```elixir
{:__slipstream__, event_struct}
```

where `event_struct` is any struct from `Slipstream.Events`.

## Events and Commands

Slipstream separates out messages into two categories: events
and commands. To some extent, Slipstream follows the [Event
Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) and [Command
Pattern](https://en.wikipedia.org/wiki/Command_pattern) design patterns with
this choice.

One might think to implement the communication between the [connection and
server processes](#process-architecture) by using data structures like
`%Message{}` and `%Reply{}` and `%Heartbeat{}`, but it's not exactly clear
who should send which message to whom. Should the connection process be sending
`%Message{}` to the server, or vice-versa? Could we re-use that data structure
for both directions?

Slipstream's `Slipstream.Events` and `Slipstream.Commands` data structures
keep this boundary clear. The server process sends commands to the connection
process when it seeks to change the connection state (join/leave) or push
a message. The connection process notifies the server of its status and how
the connection changes (whenever it changes meaningfully), with events. Events
declare how the connection has changed, which informs the server process of how
it should change the state of the `t:Slipstream.Socket.t/0` as the connection
evolves.

Events are written in the past tense in the form of `NounVerbed`, as in
`ThingHappened`, while commands are written in the form of `VerbNoun`, as in
`DoThing`.
