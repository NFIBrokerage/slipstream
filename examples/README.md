# Examples

Slipstream provides a number of example socket client implementations as both a
tutorial-like guide and a reference for common implementation patterns.

Each of these examples is tested (via `mix test`), so each example is assured to
be in working order by every green check-mark from the CI.

## Format

Each example is contained in a directory in `./examples` (the current
directory). Each example contains a `README.md` with:

- a description of the example and what it tries to solve
- a tutorial-like listing of commits that created the example, along with
  explanations of each step

In order to use the examples as a tutorial, try reading through each commit
and reproducing the client in an example project.

## Directory

- Graceful Startup: a client that handles failures in configuration at start-up
  time with graceful degradation
