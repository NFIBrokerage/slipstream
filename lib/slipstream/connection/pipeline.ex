defmodule Slipstream.Connection.Pipeline do
  @moduledoc false
  @moduledoc since: "0.3.0"

  import Slipstream.Signatures
  import Slipstream.Connection.Impl, only: [gun: 0, route_event: 2]
  alias Slipstream.Connection.{Impl, State, Telemetry}
  alias Slipstream.{Commands, Events}
  alias Phoenix.Socket.Message

  require Logger

  defstruct [
    :state,
    :raw_message,
    :message,
    :return,
    events: [],
    built_events: []
  ]

  @type t :: %__MODULE__{}

  @spec handle(raw_message :: term(), state :: %State{}) :: term()
  def handle(raw_message, state) do
    pipeline = %__MODULE__{
      raw_message: raw_message,
      state: state
    }

    Telemetry.span(
      pipeline,
      fn ->
        pipeline
        |> decode_message()
        |> handle_message()
        |> default_return()
        |> build_events()
        |> emit_events()
      end
    )
  end

  @spec decode_message(t()) :: t()
  defp decode_message(%{raw_message: command(_) = cmd} = p) do
    put_message(p, cmd)
  end

  defp decode_message(%{raw_message: :connect} = p) do
    put_message(p, :connect)
  end

  defp decode_message(
         %{
           raw_message: {:DOWN, ref, :process, _pid, reason},
           state: %{client_ref: ref}
         } = p
       ) do
    put_message(p, event(%Events.ParentProcessExited{reason: reason}))
  end

  defp decode_message(
         %{raw_message: {:gun_up, conn, _protocol}, state: %{conn: conn}} = p
       ) do
    put_message(p, event(%Events.NoOp{}))
  end

  defp decode_message(
         %{
           raw_message:
             {:gun_upgrade, conn, stream_ref, ["websocket"], resp_headers},
           state: %{conn: conn, stream_ref: stream_ref} = state
         } = p
       ) do
    put_message(
      p,
      event(%Events.ChannelConnected{
        pid: self(),
        config: state.config,
        response_headers: resp_headers
      })
    )
  end

  defp decode_message(
         %{
           raw_message: {:gun_down, conn, _protocol, _reason, affected_refs, _},
           state: %{conn: conn, stream_ref: stream_ref}
         } = p
       ) do
    if stream_ref in affected_refs do
      put_message(p, event(%Events.ChannelClosed{reason: :closed_by_remote}))
    else
      # coveralls-ignore-start
      put_message(p, event(%Events.NoOp{}))

      # coveralls-ignore-stop
    end
  end

  defp decode_message(
         %{
           raw_message:
             {:gun_error, conn, {:websocket, stream_ref, _, _, _},
              {:closed, 'The connection was lost.'}},
           state: %{conn: conn, stream_ref: stream_ref}
         } = p
       ) do
    put_message(p, event(%Events.ChannelClosed{reason: :connection_lost}))
  end

  defp decode_message(
         %{
           raw_message: {:gun_ws, conn, stream_ref, frame},
           state: %{conn: conn, stream_ref: stream_ref} = state
         } = p
       ) do
    event =
      frame
      |> Impl.decode_message(state)
      |> Events.map(state)

    put_message(p, event(event))
  end

  defp decode_message(
         %{
           raw_message:
             {:gun_response, conn, stream_ref, :nofin, status_code,
              resp_headers},
           state: %{conn: conn, stream_ref: stream_ref} = state
         } = p
       ) do
    receive do
      {:gun_data, ^conn, {:websocket, ^stream_ref, request_id, _, _}, :fin,
       response} ->
        response =
          case Impl.decode(response, state) do
            {:ok, json} ->
              json

            # coveralls-ignore-start
            _ ->
              response
              # coveralls-ignore-stop
          end

        event = %Events.ChannelConnectFailed{
          request_id: request_id,
          status_code: status_code,
          resp_headers: resp_headers,
          response: response
        }

        put_message(p, event(event))
    after
      # coveralls-ignore-start
      5_000 ->
        exit(:timeout)

        # coveralls-ignore-stop
    end
  end

  # coveralls-ignore-start
  defp decode_message(%{raw_message: unknown_message} = p) do
    Logger.error(
      """
      unknown message #{inspect(unknown_message)}
      heard in #{inspect(__MODULE__)}
      please open an issue in NFIBrokerage/slipstream with this message and
      any available information.
      """
      |> String.replace("\n", " ")
      |> String.trim()
    )

    put_message(p, event(%Events.NoOp{}))
  end

  # coveralls-ignore-stop

  @spec handle_message(t()) :: t()
  defp handle_message(%{message: :connect, state: state} = p) do
    put_state(p, Impl.connect(state))
  end

  # handle commands

  defp handle_message(%{message: command(%Commands.CollectGarbage{})} = p) do
    :erlang.garbage_collect(self())

    p
  end

  defp handle_message(
         %{message: command(%Commands.SendHeartbeat{}), state: state} = p
       ) do
    case state.heartbeat_ref do
      nil ->
        state = State.next_heartbeat_ref(state)

        Impl.push_heartbeat(state)

        p |> put_state(state)

      existing_heartbeat_ref when is_binary(existing_heartbeat_ref) ->
        # the heartbeat_ref has not been cleared, meaning the server has not
        # ack-ed our last heartbeat. This is heartbeat-timeout and it's time to
        # disconnect and shut down
        gun().close(state.conn)

        p
        |> put_event(:channel_closed, reason: :heartbeat_timeout)
        |> put_return({:stop, {:shutdown, :disconnected}, state})
    end
  end

  defp handle_message(
         %{message: command(%Commands.PushMessage{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)

    Impl.push_message(
      %Message{
        topic: cmd.topic,
        event: cmd.event,
        payload: cmd.payload,
        ref: ref
      },
      state
    )

    p
    |> put_state(state)
    |> put_return({:reply, ref, state})
  end

  defp handle_message(
         %{message: command(%Commands.JoinTopic{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)
    state = %State{state | joins: Map.put(state.joins, cmd.topic, ref)}

    Impl.push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_join",
        payload: cmd.payload,
        ref: state.current_ref_str,
        join_ref: state.current_ref_str
      },
      state
    )

    put_state(p, state)
  end

  defp handle_message(
         %{message: command(%Commands.LeaveTopic{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)
    state = %State{state | leaves: Map.put(state.leaves, cmd.topic, ref)}

    Impl.push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_leave",
        payload: %{},
        ref: state.current_ref_str
      },
      state
    )

    put_state(p, state)
  end

  defp handle_message(
         %{message: command(%Commands.CloseConnection{}), state: state} = p
       ) do
    gun().close(state.conn)

    p
    |> put_event(:channel_closed, reason: :client_disconnect_requested)
    |> put_return({:stop, {:shutdown, :disconnected}, state})
  end

  # handle events

  defp handle_message(%{message: event(%Events.NoOp{})} = p), do: p

  defp handle_message(
         %{
           message: event(%Events.ParentProcessExited{reason: reason}),
           state: state
         } = p
       ) do
    gun().close(state.conn)

    put_return(p, {:stop, reason, state})
  end

  defp handle_message(%{message: event(%Events.PingReceived{})} = p) do
    gun().ws_send(p.state.conn, :pong)

    p
  end

  defp handle_message(%{message: event(%Events.PongReceived{})} = p), do: p

  defp handle_message(%{message: event(%type{} = event), state: state} = p)
       when type in [Events.TopicJoinFailed, Events.TopicJoinClosed] do
    state = %State{state | joins: Map.delete(state.joins, event.topic)}

    route_event state, event

    put_state(p, state)
  end

  defp handle_message(
         %{message: event(%Events.TopicLeaveAccepted{} = event), state: state} =
           p
       ) do
    state = %State{state | leaves: Map.delete(state.leaves, event.topic)}

    put_state(p, state)
  end

  defp handle_message(
         %{message: event(%Events.HeartbeatAcknowledged{}), state: state} = p
       ) do
    put_state(p, State.reset_heartbeat(state))
  end

  defp handle_message(
         %{message: event(%Events.ChannelConnected{} = event), state: state} = p
       ) do
    timer =
      if state.config.heartbeat_interval_msec != 0 do
        :timer.send_interval(
          state.config.heartbeat_interval_msec,
          command(%Commands.SendHeartbeat{})
        )
      end

    state =
      %State{state | status: :connected, heartbeat_timer: timer}
      |> State.reset_heartbeat()

    route_event state, event

    put_state(p, state)
  end

  defp handle_message(
         %{message: event(%Events.ChannelClosed{} = event), state: state} = p
       ) do
    gun().close(state.conn)

    if state.heartbeat_timer |> is_reference() do
      # coveralls-ignore-start
      :timer.cancel(state.heartbeat_timer)

      # coveralls-ignore-stop
    end

    state = %State{state | status: :terminating}

    route_event state, event

    p
    |> put_state(state)
    |> put_return({:stop, :normal, state})
  end

  # the rest of the events are routed to the client process
  defp handle_message(%{message: event(event), state: state} = p) do
    route_event state, event

    p
  end

  # coveralls-ignore-start
  defp handle_message(%{message: message} = p) do
    Logger.error(
      """
      #{inspect(__MODULE__)} received a message it is not setup to handle:
      #{inspect(message)}.
      Please open an issue in NFIBrokerage/slipstream with any available details
      leading to this logger message.
      """
      |> String.replace("\n", "")
      |> String.trim()
    )

    p
  end

  # coveralls-ignore-stop

  @spec default_return(t()) :: t()
  defp default_return(%{state: state, return: nil} = p) do
    put_return(p, {:noreply, state})
  end

  defp default_return(p), do: p

  @spec build_events(t()) :: t()
  defp build_events(%{events: []} = p), do: p

  defp build_events(%{events: events} = p) do
    built_events =
      Enum.map(events, fn %{type: type, attrs: attrs} ->
        build_event(type, attrs)
      end)

    %__MODULE__{p | built_events: built_events}
  end

  defp emit_events(%{built_events: []} = p), do: p

  defp emit_events(%{built_events: events, state: state} = p) do
    Enum.each(events, fn event ->
      route_event state, event
    end)

    p
  end

  defp build_event(:channel_closed, attrs) do
    %Events.ChannelClosed{reason: attrs.reason}
  end

  # --- token API

  @spec put_state(t(), %State{}) :: t()
  def put_state(p, state) do
    %__MODULE__{p | state: state}
  end

  @spec put_message(t(), term()) :: t()
  def put_message(p, message) do
    %__MODULE__{p | message: message}
  end

  @doc """
  Adds an event to be emitted

  Note that this will not be the actual event to-be-sent, but an atom used to
  build the event in the `build_events/1` phase of the pipeline
  """
  @spec put_event(t(), atom(), Keyword.t() | map()) :: t()
  def put_event(p, event, attrs \\ %{}) do
    %__MODULE__{
      p
      | events: p.events ++ [%{type: event, attrs: Enum.into(attrs, %{})}]
    }
  end

  @doc """
  Declares the return value of the pipeline

  This value will be given to the GenServer callback that invoked
  """
  @spec put_return(t(), term()) :: t()
  def put_return(p, return) do
    %__MODULE__{p | return: return}
  end
end
