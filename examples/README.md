# Examples

Slipstream provides a number of example socket client implementations as both a
tutorial-like guide and a reference for common implementation patterns.

Each of these examples is tested (via `mix test`), so each example is assured to
be in working order by every green check-mark from the CI.

## Format

Each example is contained in a directory in `./examples`.
Each example contains a `README.md` with:

- a description of the example and what it tries to solve
- a tutorial-like listing of commits that created the example, along with
  explanations of each step

In order to use the examples as a tutorial, try reading through each commit
and reproducing the client in an example project.

## Directory

- Graceful Startup: a client that handles failures in configuration at start-up
  time with graceful degradation
- Repeater-style Client: a client which subscribes to a topic in another
  service in order to re-publish each message as a broadcast in the client's
  service's `Phoenix.Endpoint`
- Rejoin on Reconnect: a client which re-joins all joined topics on a
  reconnection after a disconnection
- GenServer Capabilities: how to use the GenServer backend of Slipstream to
  handle GenServer messaging
