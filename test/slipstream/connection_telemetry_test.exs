defmodule Slipstream.ConnectionTelemetryTest do
  use ExUnit.Case

  @moduledoc """
  Tests that the telemetry emitted by the connection process is in the format
  we expect

  Borrows a good amount of setup code from `test/slipstream/integration_test.exs`
  """
  @moduledoc since: "0.3.0"

  @moduletag :capture_log

  @client Slipstream.GoodExample

  import Slipstream.Signatures, only: [event: 1]
  alias Slipstream.Events

  @event_names [
    ~w[slipstream connection connect start]a,
    ~w[slipstream connection connect stop]a,
    ~w[slipstream connection handle start]a,
    ~w[slipstream connection handle stop]a
  ]

  describe "given the test process is receiving telemetry events from the connection" do
    setup do
      test_proc = self()
      handler_id = "test-proc-#{inspect(test_proc)}"

      :telemetry.attach_many(
        handler_id,
        @event_names,
        fn a, b, c, _state ->
          send(test_proc, {:telemetry, a, b, c})
        end,
        :ok
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      :ok
    end

    test "when we connect and disconnect, we get expected telemetry" do
      start_supervised!({@client, self()})
      assert_receive {@client, :connected}

      assert_receive {:telemetry, [:slipstream, :connection, :connect, :start],
                      %{system_time: _}, metadata}

      assert metadata.state.status == :opened
      assert metadata.trace_id |> is_binary()
      assert metadata.connection_id |> is_binary()
      assert match?(%DateTime{}, metadata.start_time)

      stop_supervised!(@client)

      assert_receive {:telemetry, [:slipstream, :connection, :connect, :stop],
                      %{duration: _}, metadata}

      assert metadata.state.status == :opened
      assert metadata.trace_id |> is_binary()
      assert metadata.connection_id |> is_binary()
      assert match?(%DateTime{}, metadata.start_time)
    end

    test "when we successfully connect, we handle gun messages" do
      start_supervised!({@client, self()})
      assert_receive {@client, :connected}

      assert_receive {:telemetry, [:slipstream, :connection, :connect, :start],
                      %{system_time: _}, _metadata}

      assert_receive {:telemetry, [:slipstream, :connection, :handle, :stop],
                      %{duration: _},
                      %{raw_message: {:gun_upgrade, _, _, _, _}} = metadata}

      assert match?(%{message: event(%Events.ChannelConnected{})}, metadata)
    end
  end
end
