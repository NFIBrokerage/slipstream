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

  # the slipstream-specific callbacks have their own return signature, usually
  # in the form of
  #   {:ok, new_state} | {:stop, reason :: term(), new_state} when new_state: term
  def map_novel_callback_return({:ok, implementor_state}, state) do
    {:noreply, %State{state | implementor_state: implementor_state}}
  end

  def map_novel_callback_return({:stop, reason, implementor_state}, state) do
    {:stop, reason, %State{state | implementor_state: implementor_state}}
  end

  def map_novel_callback_return(unmatch_signature, _state) do
    raise(ArgumentError,
      message:
        """
        Unmatched signature #{inspect(unmatch_signature)}. Expected a return value
        matching the spec:

            {:ok, new_state} | {:stop, reason :: term(), new_state} when new_state: term()
        """
        |> String.trim_leading()
    )
  end

  def push_message(message, state) do
    payload =
      message
      |> Map.from_struct()
      |> encode_fn(state).()

    :gun.ws_send(state.connection_conn, {:binary, payload})
  end

  def push_heartbeat(state) do
    payload =
      %{
        event: "heartbeat",
        topic: "phoenix",
        ref: state.heartbeat_ref,
        payload: %{}
      }
      |> encode_fn(state).()

    :gun.ws_send(state.connection_conn, {:binary, payload})
  end

  defp encode_fn(state) do
    module = state.connection_configuration.json_parser

    if function_exported?(module, :encode_to_iodata!, 1) do
      &module.encode_to_iodata!/1
    else
      &module.encode!/1
    end
  end

  defp decode_fn(state) do
    module = state.connection_configuration.json_parser

    &module.decode/1
  end

  # try decoding as json
  def decode_message({encoding, message}, state)
      when encoding in [:text, :binary] and is_binary(message) do
    case decode_fn(state).(message) do
      {:ok, decoded_json} -> Phoenix.Socket.Message.from_map!(decoded_json)
      {:error, _any} -> message
    end
  end

  def decode_message(:ping, _state), do: :ping
  def decode_message(:pong, _state), do: :pong

  def decode_message({:close, timeout, reason}, _state) do
    {:close, timeout, reason}
  end

  # does a retry with back-off based on the lists of backoff times stored
  # in the connection configuration
  def retry_time(:reconnect, %State{} = state) do
    backoff_times = state.connection_configuration.reconnect_after_msec
    try_number = state.reconnect_try_number

    retry_time(backoff_times, try_number)
  end

  def retry_time(:rejoin, %State{} = state) do
    backoff_times = state.connection_configuration.rejoin_after_msec
    try_number = state.rejoin_try_number

    retry_time(backoff_times, try_number)
  end

  def retry_time(backoff_times, try_number)
      when is_list(backoff_times) and is_integer(try_number) and try_number > 0 do
    # if the index goes beyond the length of the list, we always return
    # the final element in the list
    default = Enum.at(backoff_times, -1)

    Enum.at(backoff_times, try_number, default)
  end

  # N.B. this is storing the ref in the process dictionary, which is a
  # historically crappy thing to do. We do it in slipstream because
  # `Slipstream.push/2` needs to return a ref, although that function is only
  # invoked from the implementor, who does not have access to the outer
  # Slipstream.Connection's state. ofc we could reach into that state with
  # `:sys.get_state(self())`, but that's even grosser IMHO than the process
  # dictionary
  def next_ref do
    ref = Process.get(:slipstream_ref, 0) + 1
    Process.put(:slipstream_ref, ref)
    to_string(ref)
  end
end
