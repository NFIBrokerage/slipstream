defmodule Slipstream.SocketTest do
  @moduledoc """
  Helper functions and macros for testing Slipstream clients

  This module is something of a correlary to `Phoenix.ChannelTest`. The
  functions and macros in `Phoenix.ChannelTest` simulate client operations:
  functions like `Phoenix.ChannelTest.join/2`, `Phoenix.ChannelTest.push/3`,
  etc.. Functions and macros in this module simulate behavior of the server:
  a `Phoenix.Channel`.

  ## Timing assumptions

  Clients are typically written to assume that the server

  - is up at time of client start-up
  - is always up

  While this is typically (at least mostly) accurate, it is not necessarily
  true in general and will not be true when testing Slipstream clients. In
  particular, Slipstream clients may fail in test-mode under the following
  conditions:

  - the client is started immediately in the application supervision tree
  - it awaits a connection synchronously (with `Slipstream.await_connect/2`)
  - the testing suite takes longer to complete than the timeout given to
    `Slipstream.await_connect/2`

  While a client that uses `Slipstream.await_connect/2` can band-aid over
  these problems with a high enough timeout, clients should be satisfied with
  receiving successful connection events asynchronously. Clients written in
  the asynchronous callback style will not be affected.

  ## Setting up a test

  Another assumption clients typically make of servers is that clients assume
  there is just _one_ server. A client is not written expecting to hear that it
  has been connected multiple times for one request to `Slipstream.connect/2`.
  As such, tests using this module as a case template should be run
  synchronously.

      defmodule MyApp.MyClientTest do
        use Slipstream.SocketTest

        ..
  """

  # implementation note:
  # Getting events to the client process is not difficult.
  # The author simply must provide the pid or GenServer name. Seizing the
  # commands being emitted by the client and sent to the connection process is
  # the name of the game. We do this with two edits to the usual behavior of a
  # client:
  #
  #   1. do not spawn a connection process with `Slipstream.connect/2`
  #   2. send a `Slipstream.Events.ChannelConnected` with a pid of the current
  #      test process

  use ExUnit.CaseTemplate

  import Slipstream.Signatures, only: [event: 1, command: 1]

  alias Slipstream.Events

  alias __MODULE__.Server

  @txt_raw 5
  _ = @txt_raw

  using do
    quote do
      import unquote(__MODULE__), only: []
    end
  end

  # I reserve the right to change whatever a "server" really is.
  # For now though, a pid is as simple as it gets
  defguardp is_server(server), do: is_pid(server)

  setup do
    [server: Server.new(self())]
  end

  @doc """
  Simulates a server telling the client it has connected.

  See [Timing Assumptions](#module-timing-assumptions).

  ## Examples

      test "the server connects", c do
        connect(c.server, MyApp.MyClient)
      end
  """
  @doc since: "0.2.0"
  @spec connect(server(), pid() | GenServer.name()) :: server()
  def connect(server, client) when is_pid(client) or is_atom(client) do
    send(client, event(%Events.ChannelConnected{pid: server}))

    Server.put_client(server, client)
  end

  defmacro assert_join(server, topic_expr, params_expr, response, timeout \\ @txt_raw) do
    quote do
      assert_receive command(%Commands.JoinTopic{topic: unquote(topic_expr), payload: unquote(params_expr)}), unquote(timeout)

      send_or_raise(server, map_response_to_join_event(unquote(response)))
    end
  end

  defmacro assert_push(server, topic_expr, event_expr, params_expr, timeout \\ @txt_raw) do
  end

  defmacro assert_leave(server, topic_expr, timeout \\ @txt_raw) do
  end

  defmacro assert_disconnect(server, timeout \\ @txt_raw) do
  end

  def push

  def reply(ref, response)
end
