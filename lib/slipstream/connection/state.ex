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

  def next_ref(state) do
    ref = state.current_ref + 1

    {to_string(ref),
     %__MODULE__{state | current_ref: ref, current_ref_str: to_string(ref)}}
  end

  def reset_heartbeat(state) do
    %__MODULE__{state | heartbeat_ref: nil}
  end

  def join_ref?(%__MODULE__{joins: joins}, ref), do: ref in Map.values(joins)

  def leave_ref?(%__MODULE__{leaves: leaves}, ref),
    do: ref in Map.values(leaves)

  # update the state given any command
  # this is done before handling the command, so it's an appropriate place
  # to take next_ref/1s
  @spec apply_command(%__MODULE__{}, command :: struct()) :: %__MODULE__{}
  def apply_command(state, command)

  def apply_command(%__MODULE__{} = state, %Commands.SendHeartbeat{}) do
    {ref, state} = next_ref(state)

    %__MODULE__{state | heartbeat_ref: ref}
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
