defmodule Slipstream.Connection.Pipeline do
  @moduledoc false
  @moduledoc since: "0.3.0"

  import Slipstream.Signatures
  import Slipstream.Connection.Impl, only: [route_event: 2]
  alias Slipstream.Connection.{Impl, State, Telemetry}
  alias Slipstream.{Commands, Events, Message}

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
         %{
           raw_message: [
             {:status, ref, status},
             {:headers, ref, headers} | _maybe_done
           ],
           state: %{request_ref: ref} = state
         } = p
       ) do
    case Mint.WebSocket.new(state.conn, ref, status, headers) do
      {:ok, conn, websocket} ->
        p
        |> put_message(
          event(%Events.ChannelConnected{
            pid: self(),
            config: state.config,
            response_headers: headers
          })
        )
        |> put_state(%State{p.state | conn: conn, websocket: websocket})

      {:error, _conn, reason} ->
        failure_info = %{
          status_code: status,
          resp_headers: headers,
          reason: reason
        }

        event = %Events.ChannelConnectFailed{
          reason: {:upgrade_failure, failure_info}
        }

        put_message(p, event(event))
    end
  end

  defp decode_message(
         %{raw_message: messages, state: %{request_ref: ref} = state} = p
       ) when is_list(messages) do
    frames =
      Enum.reduce_while(messages, {:ok, state, []}, fn
        {:data, ^ref, data}, {:ok, state, acc} ->
          case Mint.WebSocket.decode(state.websocket, data) do
            {:ok, websocket, frames} ->
              {:cont, {:ok, put_in(state.websocket, websocket), acc ++ frames}}

            {:error, reason} ->
              {:halt, {:error, state, reason}}
          end

        _message, {:ok, state, acc} ->
          {:cont, {:ok, state, acc}}
      end)

    case frames do
      {:ok, state, frames} ->
        events =
          Enum.map(frames, fn frame ->
            event(frame |> Impl.decode_message(state) |> Events.map(state))
          end)

        p
        |> put_state(state)
        |> put_message(events)

      {:error, state, reason} ->
        p
        |> put_state(state)
        |> put_message(event(%Events.ChannelClosed{reason: reason}))
    end
  end

  defp decode_message(p) do
    case Mint.HTTP.stream(p.state.conn, p.raw_message) do
      {:ok, conn, messages} ->
        put_in(p.raw_message, messages)
        |> put_state(%State{p.state | conn: conn})
        |> decode_message()

      :unknown ->
        # coveralls-ignore-start
        Logger.error(
          """
          unknown message #{inspect(p.raw_message)}
          heard in #{inspect(__MODULE__)}
          please open an issue in NFIBrokerage/slipstream with this message and
          any available information.
          """
          |> String.replace("\n", " ")
          |> String.trim()
        )

        put_message(p, event(%Events.NoOp{}))
        # coveralls-ignore-stop
    end
  end

  @spec handle_message(t()) :: t()
  defp handle_message(
         %{message: :connect, state: %{config: config} = state} = p
       ) do
    with {:ok, conn} <- Impl.http_connect(config),
         {_conn, {:ok, conn, ref}} <-
           {conn, Impl.websocket_upgrade(conn, config)} do
      put_state(p, %State{state | conn: conn, request_ref: ref})
    else
      {conn, {:error, reason}} ->
        Mint.HTTP.close(conn)

        p
        |> put_event(:channel_connect_failed, reason: reason)
        |> put_return({:stop, {:shutdown, :normal}, state})

      {:error, reason} ->
        p
        |> put_event(:channel_connect_failed, reason: reason)
        |> put_return({:stop, {:shutdown, :normal}, state})
    end
  end

  defp handle_message(%{message: messages} = p) when is_list(messages) do
    Enum.reduce_while(messages, p, fn
      _message, %{return: {:stop, _reason, _state}} = p ->
        {:halt, p}

      message, p ->
        {:cont, handle_message(%{p | message: message})}
    end)
  end

  # handle commands

  defp handle_message(%{message: command(%Commands.CollectGarbage{})} = p) do
    :erlang.garbage_collect(self())

    p
  end

  defp handle_message(
         %{message: command(%Commands.SendHeartbeat{}), state: state} = p
       ) do
    with nil <- state.heartbeat_ref,
         {:ok, state} <- state |> State.next_heartbeat_ref()|> Impl.push_heartbeat() do
      put_state(p, state)
    else
      existing_heartbeat_ref when is_binary(existing_heartbeat_ref) ->
        # the heartbeat_ref has not been cleared, meaning the server has not
        # ack-ed our last heartbeat. This is heartbeat-timeout and it's time to
        # disconnect and shut down
        Mint.HTTP.close(state.conn)

        p
        |> put_event(:channel_closed, reason: :heartbeat_timeout)
        |> put_return({:stop, {:shutdown, :disconnected}, state})

      {:error, state, reason} ->
        route_event state,
                    event(%Events.ChannelClosed{reason: {:send_failure, reason}})

        put_return(p, {:stop, :normal, state})
    end
  end

  defp handle_message(
         %{message: command(%Commands.PushMessage{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)

    p =
      p
      |> put_state(state)
      |> push_message(
        %Message{
          topic: cmd.topic,
          event: cmd.event,
          payload: cmd.payload,
          ref: ref
        }
      )

    case p do
      %{return: {:stop, _reason, _state}} = p -> p
      p -> put_return(p, {:reply, ref, state})
    end
  end

  defp handle_message(
         %{message: command(%Commands.JoinTopic{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)
    state = %State{state | joins: Map.put(state.joins, cmd.topic, ref)}

    p
    |> put_state(state)
    |> push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_join",
        payload: cmd.payload,
        ref: state.current_ref_str,
        join_ref: state.current_ref_str
      }
    )
  end

  defp handle_message(
         %{message: command(%Commands.LeaveTopic{} = cmd), state: state} = p
       ) do
    {ref, state} = State.next_ref(state)
    state = %State{state | leaves: Map.put(state.leaves, cmd.topic, ref)}

    p
    |> put_state(state)
    |> push_message(
      %Message{
        topic: cmd.topic,
        event: "phx_leave",
        payload: %{},
        ref: state.current_ref_str
      }
    )
  end

  defp handle_message(
         %{message: command(%Commands.CloseConnection{}), state: state} = p
       ) do
    Mint.HTTP.close(state.conn)

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
    Mint.HTTP.close(state.conn)

    put_return(p, {:stop, reason, state})
  end

  defp handle_message(
         %{
           message: event(%Events.ChannelConnectFailed{} = event),
           state: state
         } = p
       ) do
    Mint.HTTP.close(state.conn)

    route_event state, event

    put_return(p, {:stop, :normal, state})
  end

  defp handle_message(%{message: event(%Events.PingReceived{data: data})} = p) do
    push_message(p, {:pong, data})
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
        {:ok, tref} =
          :timer.send_interval(
            state.config.heartbeat_interval_msec,
            command(%Commands.SendHeartbeat{})
          )

        tref
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
    Mint.HTTP.close(state.conn)

    if match?({:interval, ref} when is_reference(ref), state.heartbeat_timer) do
      :timer.cancel(state.heartbeat_timer)
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

  defp build_event(:channel_connect_failed, attrs) do
    %Events.ChannelConnectFailed{reason: attrs.reason}
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

  def push_message(p, message) do
    case Impl.push_message(message, p.state) do
      {:ok, state} ->
        put_state(p, state)

      {:error, reason} ->
        route_event p.state,
                    event(%Events.ChannelClosed{reason: {:send_failure, reason}})

        put_return(p, {:stop, :normal, p.state})
    end
  end
end
