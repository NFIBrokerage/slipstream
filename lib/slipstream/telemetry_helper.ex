defmodule Slipstream.TelemetryHelper do
  @moduledoc false
  @moduledoc since: "0.4.0"

  alias Slipstream.{Socket, Events}

  @doc since: "0.4.0"
  def id(length \\ 16) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
    |> binary_part(0, length)
    |> String.downcase()
  end

  @doc since: "0.4.0"
  def trace_id, do: id(32)

  @doc """
  Emits a start event for an attempt to connect

  Emitted in cases of a client using `Slipstream.connect/2`,
  `Slipstream.connect!/2` or `Slipstream.reconnect/1`.
  """
  @doc since: "0.4.0"
  @spec begin_connect(Socket.t(), Slipstream.Configuration.t()) :: Socket.t()
  def begin_connect(socket, config) do
    metadata = %{
      start_time: DateTime.utc_now(),
      start_time_monotonic: :erlang.monotonic_time(),
      configuration: config,
      socket: clean_socket(socket)
    }

    :telemetry.execute(
      [:slipstream, :client, :connect, :start],
      %{system_time: :erlang.system_time()},
      Map.delete(metadata, :start_time_monotonic)
    )

    put_in(socket, [Access.key(:metadata), :connect], metadata)
  end

  @doc """
  Emits a stop event for an attempt to connect

  Emitted when the connection process tells the client that it has successfully
  connected with a `Slipstream.Events.ChannelConnected` event.
  """
  @doc since: "0.4.0"
  @spec conclude_connect(Socket.t(), Events.ChannelConnected.t()) :: Socket.t()
  def conclude_connect(
        %Socket{metadata: %{connect: start_metadata}} = socket,
        event
      )
      when is_map(start_metadata) and map_size(start_metadata) > 0 do
    metadata =
      start_metadata
      |> Map.merge(%{
        response_headers: event.response_headers,
        socket: clean_socket(socket)
      })
      |> Map.delete(:start_time_monotonic)

    duration = :erlang.monotonic_time() - start_metadata.start_time_monotonic

    :telemetry.execute(
      [:slipstream, :client, :connect, :stop],
      %{duration: duration},
      metadata
    )

    %{socket | metadata: Map.delete(socket.metadata, :connect)}
  end

  # technically speaking this case doesn't make any sense... you need to connect
  # in order to conclude connecting, but /shrug just putting it here to not
  # crash over some spilled telemetry
  # coveralls-ignore-start
  def conclude_connect(socket, _event), do: socket

  # coveralls-ignore-stop

  # YARD emit exception event for failure to connect and another when failed to
  # join?

  @doc """
  Emits a start event for an attempt to join

  Emitted in cases of a client using `Slipstream.join/3` or
  `Slipstream.rejoin/3`.
  """
  @doc since: "0.4.0"
  @spec begin_join(
          Socket.t(),
          topic :: String.t(),
          params :: Slipstream.json_serializable()
        ) :: Socket.t()
  def begin_join(socket, topic, params) do
    metadata = %{
      start_time: DateTime.utc_now(),
      start_time_monotonic: :erlang.monotonic_time(),
      socket: clean_socket(socket),
      topic: topic,
      params: params
    }

    :telemetry.execute(
      [:slipstream, :client, :join, :start],
      %{system_time: :erlang.system_time()},
      Map.delete(metadata, :start_time_monotonic)
    )

    put_in(socket, [Access.key(:metadata), :joins, topic], metadata)
  end

  @doc """
  Emits a stop event for an attempt to join

  Emitted when the connection process tells the client that it has successfully
  connected with a `Slipstream.Events.TopicJoinSucceeded` event.
  """
  @doc since: "0.4.0"
  @spec conclude_join(Socket.t(), Events.TopicJoinSucceeded.t()) :: Socket.t()
  def conclude_join(socket, event) do
    case Map.fetch(socket.metadata.joins, event.topic) do
      {:ok, start_metadata} ->
        metadata =
          start_metadata
          |> Map.merge(%{
            socket: clean_socket(socket),
            response: event.response
          })
          |> Map.delete(:start_time_monotonic)

        duration =
          :erlang.monotonic_time() - start_metadata.start_time_monotonic

        :telemetry.execute(
          [:slipstream, :client, :join, :stop],
          %{duration: duration},
          metadata
        )

        update_in(
          socket,
          [Access.key(:metadata), :joins],
          &Map.delete(&1, event.topic)
        )

      :error ->
        # again, this doesn't make sense, but I'd rather not crash if I'm wrong
        # coveralls-ignore-start
        socket

        # coveralls-ignore-stop
    end
  end

  @doc """
  Wraps a callback dispatch to a Slipstream client module
  """
  @doc since: "0.4.0"
  def wrap_dispatch(module, function, args, func) do
    metadata = %{
      client: module,
      callback: function,
      arguments: args,
      socket: clean_socket(List.last(args)),
      start_time: DateTime.utc_now()
    }

    return_value =
      :telemetry.span(
        [:slipstream, :client, function],
        metadata,
        fn ->
          return = func.()

          metadata =
            Map.merge(metadata, %{
              return: return
            })

          {return, metadata}
        end
      )

    return_value
  end

  defp clean_socket(%Slipstream.Socket{} = socket) do
    # Clear metadata from the socket. The socket contains the metadata and
    # the metadata contains the socket so if we repeatedly "begin" operations
    # like connects or joins, we cause sharp memory growth in the client and
    # connection processes.
    %{socket | metadata: %{}}
  end
end
