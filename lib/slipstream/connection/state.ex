defmodule Slipstream.Connection.State do
  @moduledoc false

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
    joins: %{},
    current_ref: 0,
    current_ref_str: "0",
    reconnect_try_number: 0
    # rejoin_try_number: 0
  ]

  def next_ref(state) do
    ref = state.current_ref + 1

    {to_string(ref), %__MODULE__{state | current_ref: ref}}
  end

  def next_heartbeat_ref(state) do
    {ref, state} = next_ref(state)

    %__MODULE__{state | heartbeat_ref: ref}
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
end
