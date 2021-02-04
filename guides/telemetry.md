# Telemetry

Slipstream currently emits telemetry for each message received in its
`Slipstream.Connection` process. This aides in low-level debugging when one
desires to see the entire event-history of a connection. Telemetry support is
also desired for clients, but has yet to be implemented. See
[#4](https://github.com/NFIBrokerage/slipstream/issues/4).

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
