defmodule Slipstream.Connection.Impl do
  @moduledoc false

  alias Slipstream.Connection.State

  # helper functions for the Connection

  # an enumeration of all valid return values for GenServer callbacks which
  # declare new state
  def map_genserver_return({:ok, implementor_state}, state) do
    {:ok, %State{state | implementor_state: implementor_state}}
  end

  def map_genserver_return({:ok, implementor_state, other_stuff}, state) do
    {:ok, %State{state | implementor_state: implementor_state}, other_stuff}
  end

  def map_genserver_return({:reply, reply, implementor_state}, state) do
    {:reply, reply, %State{state | implementor_state: implementor_state}}
  end

  def map_genserver_return(
         {:reply, reply, implementor_state, other_stuff},
         state
       ) do
    {:reply, reply, %State{state | implementor_state: implementor_state},
     other_stuff}
  end

  def map_genserver_return({:noreply, implementor_state}, state) do
    {:noreply, %State{state | implementor_state: implementor_state}}
  end

  def map_genserver_return({:noreply, implementor_state, other_stuff}, state) do
    {:noreply, %State{state | implementor_state: implementor_state},
     other_stuff}
  end

  def map_genserver_return({:stop, reason, reply, implementor_state}, state) do
    {:stop, reason, reply, %State{state | implementor_state: implementor_state}}
  end

  def map_genserver_return({:stop, reason, implementor_state}, state) do
    {:stop, reason, %State{state | implementor_state: implementor_state}}
  end

  def map_genserver_return(other, _state), do: other

  def push_message(message, state) do
    payload =
      %{
        join_ref: state.join_ref,
        ref: state.current_ref,
        topic: state.topic
      }
      |> Map.merge(message)
      |> encode_fn(state).()

    :gun.ws_send(state.connection_conn, {:binary, payload})
  end

  defp encode_fn(state) do
    module = Keyword.fetch!(state.connection_configuration, :json_parser)

    if function_exported?(module, :encode_to_iodata!, 1) do
      &module.encode_to_iodata!/1
    else
      &module.encode!/1
    end
  end

  defp decode_fn(state) do
    module = Keyword.fetch!(state.connection_configuration, :json_parser)

    &module.decode/1
  end

  # try decoding as json
  def decode_message({encoding, message}, state) when encoding in [:text, :binary] and is_binary(message) do
    case decode_fn(state).(message) do
      {:ok, decoded_json} -> decoded_json
      {:error, _any} -> message
    end
  end

  def decode_message(:ping, _state), do: :ping
  def decode_message(:pong, _state), do: :pong
end
