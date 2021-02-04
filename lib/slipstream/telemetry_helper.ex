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
  `Slipstream.connect!/2` or `Slipstream.reconnect/1`
  """
  @doc since: "0.4.0"
  @spec begin_connect(Socket.t(), Slipstream.Configuration.t()) :: Socket.t()
  def begin_connect(socket, _config) do
    socket
  end

  @doc """
  Emits a stop event for an attempt to connect

  Emitted when the connection process tells the client that it has successfully
  connected with a `Slipstream.Events.ChannelConnected` event.
  """
  @doc since: "0.4.0"
  @spec conclude_connect(Socket.t(), %Events.ChannelConnected{}) :: Socket.t()
  def conclude_connect(socket, _event) do
    socket
  end

  # YARD emit exception event for failure to connect and another when failed to
  # join?

  @doc """
  Emits a start event for an attempt to join

  Emitted in cases of a client using `Slipstream.join/3` or
  `Slipstream.rejoin/3`
  """
  @doc since: "0.4.0"
  @spec begin_join(
          Socket.t(),
          topic :: String.t(),
          params :: Slipstream.json_serializable()
        ) :: Socket.t()
  def begin_join(socket, _topic, _params) do
    socket
  end

  @doc """
  Emits a stop event for an attempt to join

  Emitted when the connection process tells the client that it has successfully
  connected with a `Slipstream.Events.TopicJoinSucceeded` event.
  """
  @doc since: "0.4.0"
  @spec conclude_join(Socket.t(), %Events.TopicJoinSucceeded{}) :: Socket.t()
  def conclude_join(socket, _event) do
    socket
  end
end
