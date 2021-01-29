defmodule Slipstream.Connection.State do
  @moduledoc false

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
    current_ref_str: "0",
    reconnect_try_number: 0
    # rejoin_try_number: 0
  ]

  def next_ref(state) do
    ref = state.current_ref + 1

    {to_string(ref),
     %__MODULE__{state | current_ref: ref, current_ref_str: to_string(ref)}}
  end

  def increment_reconnect_counter(state) do
    increment(state, :reconnect_try_number)
  end

  def reset_reconnect_try_counter(state) do
    put_in(state.reconnect_try_number, 0)
  end

  def increment_rejoin_counter(state) do
    increment(state, :rejoin_try_number)
  end

  def reset_rejoin_try_counter(state) do
    put_in(state.rejoin_try_number, 0)
  end

  defp increment(map, key) do
    Map.update(map, key, 1, &(&1 + 1))
  end

  def reset_heartbeat(state) do
    %__MODULE__{state | heartbeat_ref: nil}
  end

  def cancel_heartbeat_timer(state) do
    if state.heartbeat_timer |> is_reference() do
      :timer.cancel(state.heartbeat_timer)
    end

    state
  end

  def join_ref?(%__MODULE__{joins: joins}, ref), do: ref in Map.values(joins)

  def leave_ref?(%__MODULE__{leaves: leaves}, ref), do: ref in Map.values(leaves)

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
    %__MODULE__{state | status: :connected}
  end

  def apply_event(state, %Events.ChannelClosed{}) do
    %__MODULE__{state | status: :terminating}
  end

  def apply_event(state, _event), do: state
end
