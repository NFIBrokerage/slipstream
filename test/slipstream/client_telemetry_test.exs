defmodule Slipstream.ClientTelemetryTest do
  use ExUnit.Case

  @moduledoc """
  Tests that the telemetry emitted by the client process is in the format
  we expect

  Borrows a good amount of setup code from `test/slipstream/integration_test.exs`
  """
  @moduledoc since: "0.4.0"

  @moduletag :capture_log

  import Slipstream.PidHelpers

  @client Slipstream.GoodExample

  @event_names [
    ~w[slipstream client connect start]a,
    ~w[slipstream client connect stop]a,
    ~w[slipstream client join start]a,
    ~w[slipstream client join stop]a,
    ~w[slipstream client handle_reply stop]a
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

      assert_receive {:telemetry, [:slipstream, :client, :connect, :start],
                      %{system_time: _}, metadata}

      assert match?(%Slipstream.Configuration{}, metadata.configuration)
      assert match?(%Slipstream.Socket{}, metadata.socket)

      stop_supervised!(@client)

      assert_receive {:telemetry, [:slipstream, :client, :connect, :stop],
                      %{duration: _}, metadata}

      assert is_list(metadata.response_headers)
      assert match?(%Slipstream.Configuration{}, metadata.configuration)
      assert match?(%Slipstream.Socket{}, metadata.socket)
    end

    test "when we join a channel, we get expected telemetry" do
      topic = "test:good"
      pid = start_supervised!({@client, self()})
      assert_receive {@client, :connected}
      join(pid, topic)
      assert_receive {@client, :joined, ^topic, %{}}

      assert_receive {:telemetry, [:slipstream, :client, :join, :start],
                      %{system_time: _}, metadata}

      assert match?(%Slipstream.Socket{}, metadata.socket)
      assert metadata.topic == topic
      assert metadata.params == %{test_pid: pid_string()}

      assert_receive {:telemetry, [:slipstream, :client, :join, :stop],
                      %{duration: _}, metadata}

      assert match?(%Slipstream.Socket{}, metadata.socket)
      assert metadata.topic == topic
      assert metadata.response == %{}
    end

    test "when we receive a message, we get expected telemetry" do
      topic = "test:good"
      pid = start_supervised!({@client, self()})
      assert_receive {@client, :connected}
      join(pid, topic)
      assert_receive {@client, :joined, ^topic, %{}}
      :ok = GenServer.cast(pid, {:push, topic, "ping", %{}})

      assert_receive {@client, :received_reply, _ref,
                      {:ok, %{"pong" => "pong"}}}

      assert_receive {:telemetry, [:slipstream, :client, :handle_reply, :stop],
                      %{duration: _}, metadata}

      assert match?(%Slipstream.Socket{}, metadata.socket)
      assert match?({:noreply, _socket}, metadata.return)
      assert metadata.callback == :handle_reply
      assert metadata.client == @client
    end
  end

  defp join(pid, topic) do
    GenServer.cast(pid, {:join, topic, %{test_pid: pid_string()}})
  end
end
