# Telemetry

Slipstream emits telemetry events for both processes: the client process and
the connection process.

Telemetry for the connection process is very low-level: information about
each message and before-and-after states for the connection. This telemetry
aides in debugging failure-states of Slipstream and can be useful for
development, but is likely not worth ingesting for average Slipstream users.

Client process telemetry is similar to the telemetry emitted by
`Phoenix.Channel`s and is recommended for consumption by average Slipstream
users.

## Client-process Telemetry

Clients emit telemetry in two categories:

- basic channel connection and topic join events
- callback events

The first emulate two-of-three events emitted by `Phoenix.Channel`s (at time
of writing):

- `[:slipstream, :client, :connect]` - dispatched at the end of a successful
  client connection to a remote websocket host
    - metadata
      ```elixir
      %{
        start_time: DateTime.t(),
        configuration: Slipstream.Configuration.t(),
        socket: Slipstream.Socket.t(),
        # emitted only on the stop event:
        response_headers: [{String.t(), String.t()}]
      }
      ```
- `[:slipstream, :client, :join]` - dispatched at the end of a successful
  join onto a topic
    - metadata
      ```elixir
      %{
        start_time: DateTime.t(),
        socket: Slipstream.Socket.t(),
        topic: String.t(),
        params: Slipstream.json_serializable(),
        # emitted only on the stop event:
        response: Slipstream.json_serializable()
      }
      ```

The second is emitted for any callback defined by the `Slipstream` module. Each
of these events are emitted under the event name of
`[:slipstream, :client, callback]`, where `callback` is any callback defined
by `Slipstream`, e.g. `:handle_message`. The metadata for these events is as
follows:

```elixir
%{
  client: module(),
  callback: atom(),
  arguments: [any()],
  socket: Slipstream.Socket.t(),
  start_time: DateTime.t(),
  # emitted only on the stop event
  response: any()
}
```

Note that all client-process events emulate `:telemetry.span/3` in naming and
in measurements, and in the case of callback events, the events are emitted
by `:telemetry.span/3`. This means that each of the above-described events
are actually prefixes, and each event name below represents messages of
`event_prefix ++ [:start]` and `event_prefix ++ [:stop]`, with exceptions
being emitted as `event_prefix ++ [:exception]`.

Client authors are encouraged to only subscribe to the callbacks they are
interested in (e.g. `:handle_message` or `:handle_reply`).

## Connection-process Telemetry

Slipstream currently emits telemetry for each message received in its
`Slipstream.Connection` process. This aides in low-level debugging when one
desires to see the entire event-history of a connection.

A connection can be pieced together by the `:trace_id` and `:connection_id`
keys emitted in the metadata of these telemetry events. One
`Slipstream.Connection` process is guaranteed to only use one `:trace_id` and
one `:connection_id`.

The trace-id acts as a identifier which groups together all requests belonging
to that `Slipstream.Connection` process. Because the life-cycle of the GenServer
which runs the `Slipstream.Connection` process and the actual connection to a
remote websocket are the same, there doesn't appear to be much difference
between the `:trace_id` and the `:connection_id`, however, the `:connection_id`
can be considered the parent-ID for all spans, where each subsequent message
to the connection process is considered a span.

The `Slipstream.Connection` telemetry event prefixes are as follows:

`[:slipstream, :connection, :connect]`: an event which is executed at the
start and stop of the connection process's life-cycle.

The metadata contains:

```elixir
%{
  state: %Slipstream.Connection.State{},
  connection_id: String.t(),
  trace_id: String.t(),
  # UTC date-time stamp of start-of-connection
  start_time: DateTime.t()
}
```

`[:slipstream, :connection, :handle]`: an event executed for each message
received by the connection process.

Metadata contains:

```elixir
%{
  start_state: %Slipstream.Connection.State{},
  connection_id: String.t(),
  trace_id: String.t(),
  # unique to this message handle
  span_id: String.t(),
  # UTC date-time stamp of start-of-handling
  start_time: DateTime.t(),
  raw_message: term(),
  # included on the `event_prefix ++ [:stop]` events:
  message: term(),
  events: [%{type: atom(), attrs: map()}],
  built_events: [struct()],
  return: tuple(),
  end_state: %Slipstream.Connection.State{}
}
```

Each of these events follows the `:telemetry.span/3` pattern in measurements
and in names: `event_prefix ++ [:start]` and `event_prefix ++ [:stop]` events
are emitted using each of the above event prefixes.
