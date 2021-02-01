defmodule Slipstream.Connection.State do
  @moduledoc false

  import Slipstream.Signatures, only: [command: 1]
  alias Slipstream.{Commands, Events}

  # a struct for storing the internal state of a Slipstream.Connection
  # process

  # the module which implements the Slipstream behaviour is hereby known
  # as the implementor

  defstruct [
    :socket_pid,
    :socket_ref,
    :config,
    :conn,
    :stream_ref,
    :join_params,
    :heartbeat_timer,
    :heartbeat_ref,
    status: :opened,
    joins: %{},
    leaves: %{},
    current_ref: 0,
    current_ref_str: "0"
  ]

  @doc """
  Gets the next ref and increments the ref counter in state

  The `ref` passed between a client and phoenix server is a marker which
  can be used to link pushes to their replies. E.g. a heartbeat message from
  the client will include a ref which will match the associated heartbeat
  reply from the server, when the heartbeat is sucessful.

  Refs are simply strings of incrementing integers.
  """
  def next_ref(state) do
    ref = state.current_ref + 1

    {to_string(ref),
     %__MODULE__{state | current_ref: ref, current_ref_str: to_string(ref)}}
  end

  @doc """
  Resets the heartbeat ref to nil

  This is used to clear out a pending heartbeat. If the
  `Slipstream.Commands.SendHeartbeat` command is received and the heartbeat_ref
  in state is nil, that means we have not received a reply to our heartbeat
  request and that the server is potentially stuck or otherwise not responding.
  """
  def reset_heartbeat(state) do
    %__MODULE__{state | heartbeat_ref: nil}
  end

  @doc """
  Detects if a ref is one used to join a topic
  """
  def join_ref?(%__MODULE__{joins: joins}, ref), do: ref in Map.values(joins)

  @doc """
  Detects if a ref was used to request a topic leave
  """
  def leave_ref?(%__MODULE__{leaves: leaves}, ref),
    do: ref in Map.values(leaves)

  @doc """
  Update the state given any command

  This is done before handling the command, so it's an appropriate place
  to take `next_ref/1`s.

  Any command can modify the state before it gets handled. This separation
  between updating state and handling of commands keeps clean the boundary
  of where side-effects take place in the connection process.
  """
  @spec apply_command(%__MODULE__{}, command :: struct()) :: %__MODULE__{}
  def apply_command(state, command)

  def apply_command(
        %__MODULE__{heartbeat_ref: nil} = state,
        %Commands.SendHeartbeat{}
      ) do
    {ref, state} = next_ref(state)

    %__MODULE__{state | heartbeat_ref: ref}
  end

  def apply_command(
        %__MODULE__{heartbeat_ref: existing_heartbeat_ref} = state,
        %Commands.SendHeartbeat{}
      )
      when is_binary(existing_heartbeat_ref) do
    %__MODULE__{state | heartbeat_ref: :error}
  end

  def apply_command(%__MODULE__{} = state, %Commands.PushMessage{}) do
    {_ref, state} = next_ref(state)

    state
  end

  def apply_command(%__MODULE__{} = state, %Commands.JoinTopic{} = cmd) do
    {ref, state} = next_ref(state)

    %__MODULE__{state | joins: Map.put(state.joins, cmd.topic, ref)}
  end

  def apply_command(%__MODULE__{} = state, %Commands.LeaveTopic{} = cmd) do
    {ref, state} = next_ref(state)

    %__MODULE__{state | leaves: Map.put(state.leaves, cmd.topic, ref)}
  end

  def apply_command(state, _command), do: state

  @doc """
  Updates the state before an event is sent along to a client process

  This is mostly used to groom internal state about whether or not the
  connection process is actually connected to the remote server and whether or
  not the connection is joined to topics.
  """
  @spec apply_event(%__MODULE__{}, event :: struct()) :: %__MODULE__{}
  def apply_event(state, event)

  def apply_event(state, %type{} = event)
      when type in [Events.TopicJoinClosed, Events.TopicJoinFailed] do
    %__MODULE__{state | joins: Map.delete(state.joins, event.topic)}
  end

  def apply_event(state, %Events.TopicLeaveAccepted{} = event) do
    %__MODULE__{state | leaves: Map.delete(state.leaves, event.topic)}
  end

  def apply_event(state, %Events.HeartbeatAcknowledged{}) do
    reset_heartbeat(state)
  end

  def apply_event(state, %Events.ChannelConnected{}) do
    timer =
      if state.config.heartbeat_interval_msec != 0 do
        :timer.send_interval(
          state.config.heartbeat_interval_msec,
          command(%Commands.SendHeartbeat{})
        )
      end

    %__MODULE__{state | status: :connected, heartbeat_timer: timer}
    |> reset_heartbeat()
  end

  def apply_event(state, %Events.ChannelClosed{}) do
    if state.heartbeat_timer |> is_reference() do
      # coveralls-ignore-start
      :timer.cancel(state.heartbeat_timer)

      # coveralls-ignore-stop
    end

    %__MODULE__{state | status: :terminating}
  end

  def apply_event(state, _event), do: state
end
