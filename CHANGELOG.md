# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.8.0 - [UNRELEASED]

### Changed

- Switched out `:gun` for Mint.WebSocket as the low-level websocket client

## 0.7.0 - 2021-06-21

### Added

- Added `c:Slipstream.handle_leave/2`
    - This is invoked when the server acknowledges that the client has left
      the topic
    - This was previously invoked as the more generic
      `c:Slipstream.handle_topic_close/3`

### Changed

- Topic leaves are now handled not in `c:Slipstream.handle_topic_close/3`
  but `c:Slipstream.handle_leave/2`
    - **this is a breaking change**

In order to migrate existing code, change any implementations of
`c:Slipstream.handle_topic_close/3` with the `reason` of `:left` from

```elixir
def handle_topic_close(_topic, :left, socket)
```

To

```elixir
def handle_leave(_topic, socket)
```

Note that this callback has a default behavior of performing a no-op.

### Fixed

- Failures to connect (via an `:error` return from `c:Phoenix.Socket.connect/3`)
  now correctly trigger a `Slipstream.Events.ChannelConnectFailed` event
    - when using the synchronous API, this will result in an error tuple with
      `Slipstream.await_connect/2` in the format of
      `{:error, {:connect_failure, %{resp_headers: resp_headers, status_code: status_code}}}`
      where `status_code` will be `403`.
    - when using the module-based API, this will invoke the
      `c:Slipstream.handle_disconnect/2` callback with the same error tuple

## 0.6.2 - 2021-03-01

### Fixed

- `await_join!/2` and `await_leave!/2` have been changed to `await_join!/3`
  and `await_leave!/3` matching their intended usage
    - the `topic` parameter has been added which coincides with the API of
      `await_join/3` and `await_leave/3`

## 0.6.1 - 2021-02-27

### Fixed

- Fixed dialyzer warnings arising from some code macro-injected by
  `Slipstream.__using__/1`
    - thanks [`@jjcarstens`](https://github.com/jjcarstens)!

## 0.6.0 - 2021-02-24

### Removed

- Removed dependency on Phoenix

## 0.5.4 - 2021-02-22

### Fixed

- Slipstream will now gracefully handle failures from `:gun.open/3`
    - errors will result in an invocation of a client's
      `c:Slipstream.handle_disconnect/2` callback (if the client is a module)
      or return an error tuple from `await_connect/2` in the case of a
      synchronous client

## 0.5.3 - 2021-02-11

### Changed

- Synchronous functions are now grouped under "Synchronous Functions" in the
  documentation

## 0.5.2 - 2021-02-10

### Fixed

- The timer reference for the heartbeat interval is now properly matched upon
  in the connection process
    - this fixes some behavior where the timer reference would not be canceled
      (with `:timer.cancel/1`) upon disconnection
    - this has not manifested itself as a bug as far as we are aware, but this
      fix should properly clean up the timer when it is no longer needed

## 0.5.1 - 2021-02-08

### Added

- Added an example guide on how to use GenServer operations for a client
- Added an example on using Slipstream to script interactions with remote
  `Phoenix.Channel`s

## 0.5.0 - 2021-02-07

### Added

- Added `Slipstream.Socket.update/3` which emulates `Phoenix.LiveView.update/3`
- Added an example on the rejoin-after-reconnect pattern for clients which
  dynamically join topics

## 0.4.4 - 2021-02-07

### Fixed

- Link to post-cutover-metrics image made absolute

## 0.4.3 - 2021-02-07

### Added

- Added examples to the documentation
    - "Graceful Startup" and "Repeater-style Client"
- Added a note about post-cutover performance changes after we (NFIBrokerage)
  cutover to Slipstream in our stack
    - This is a new section in the "Why :gun?" guide
- Added documentation on counting the number of Slipstream connection processes
  to `Slipstream.ConnectionSupervisor`

## 0.4.2 - 2021-02-05

### Fixed

- Added channel config to socket on `Slipstream.connect/2` or
  `Slipstream.connect!/2`
    - this fixes an issue reconnecting when faking a connection through
      `Slipstream.SocketTest.accept_connect/1`

## 0.4.1 - 2021-02-04

### Fixed

- Changed the default behavior of `c:Slipstream.terminate/2` to disconnect
  gracefully with `Slipstream.disconnect/1`

### Added

- Added better documentation on the `c:Slipstream.terminate/2` callback and
  how to disconnect in it to leave a connection gracefully

## 0.4.0 - 2021-02-04

### Added

- Added telemetry support for clients
    - see the telemetry guide for more details

## 0.3.4 - 2021-02-04

### Fixed

- Fixed spelling and grammar mistakes in the implementation guide

## 0.3.3 - 2021-02-04

### Added

- increased documentation around retry mechanisms
- added a page on the choice of `:gun` as the low-level webscket client

## 0.3.2 - 2021-02-03

### Fixed

- Fixed edge case where the remote server shutting down would not emit a
  `ChannelClosed` event
    - this and heartbeats caused the odd `:gun_error` atom from
      [#12](https://github.com/NFIBrokerage/slipstream/issues/12)

## 0.3.1 - 2021-02-03

### Fixed

- The telemetry event for message handles in the connection process should now
  correctly publish the `:events` key, not the `:event` key
- The telemetry guide now correctly states that the `:start_state` key holds
  the connection state for handle-style events

### Added

- Published the connection state at the end of the message handle for
  handle-type telemetry events in the connection process
    - this is published in the `:end_state` key

## 0.3.0 - 2021-02-03

### Added

- `:telemetry` events are executed for each message handled by the
  `Slipstream.Connection` process
    - this should aide in debugging in scenarios in which one wants to see the
      full event history of a connection

## 0.2.4 - 2021-02-02

### Fixed

- Emit `ChannelClosed` event on HTTP close from remote websocket server
    - See [#11](https://github.com/NFIBrokerage/slipstream/issues/11)

## 0.2.3 - 2021-02-02

### Changed

- docs: the main page now shows the `Slipstream` module
    - frankly, I just want people to see the Basic Usage section as soon as
      possible so they get a taste for the library

## 0.2.2 - 2021-02-01

### Fixed

- The connection now properly disconnects when the server's heartbeat replies
  timeout with requests
    - disconnects for this reason will send have `:heartbeat_timeout` as the
      reason referenced in `c:Slipstream.handle_disconnect/2`

## 0.2.1 - 2021-02-01

### Fixed

- Connection now correctly emits ChannelClosed events for `:gun` events which
  occur when a service's network access is terminated

## 0.2.0 - 2021-02-01

### Added

- Added a testing framework `Slipstream.SocketTest`

## 0.1.4 - 2021-01-31

### Fixed

- Published license to hex

## 0.1.3 - 2021-01-30

### Changed

- Widened dependency on `:gun` from `~> 1.3` to `~> 1.0`
    - as far as I can tell, there aren't any real changes to the websocket
      interface, so any of these versions should be OK

## 0.1.2 - 2021-01-30

### Added

- More documentation
    - including a Basic Usage section with a minimalistic example

## 0.1.1 - 2021-01-30

### Removed

- Removed direct dependency on `:telemetry`
    - see #4

## 0.1.0 - 2021-01-30

### Added

- Initial implementation and initial publish

## 0.0.0 - 2021-01-22

### Added

- This project was generated by Gaas

<!-- # Generated by Elixir.Gaas.Generators.Simple.Library.Changelog -->
