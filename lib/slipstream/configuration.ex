defmodule Slipstream.Configuration do
  @definition [
    uri: [
      doc: """
      The endpoint to which the websocket will connect.
      """,
      type: {:custom, __MODULE__, :parse_uri, []},
      required: true
    ],
    heartbeat_interval_msec: [
      doc: """
      The time between heartbeat messages. A value of 0 will disable automatic
      heartbeat sending. Note that a Phoenix.Channel will close out a connection
      after 60 seconds of inactivity (`60_000`).
      """,
      type: :non_neg_integer,
      default: 30_000
    ],
    headers: [
      doc: """
      A set of headers to merge with the request headers when GETing the
      websocket URI. Headers must be provided as two-tuples where both elements
      are binaries. Casing of these headers is inconsequential.
      """,
      type: {:list, {:custom, __MODULE__, :parse_pair_of_strings, []}},
      default: []
    ],
    json_parser: [
      doc: """
      A JSON parser module which exports at least `encode/1` and `decode/2`.
      """,
      type: :atom,
      default: Jason
    ],
    reconnect_after_msec: [
      doc: """
      A list of times to reference for trying reconnection when
      `Slipstreamm.reconnect/0` is used to request reconnection. The msec time
      will be fetched based on its position in the list with
      `Enum.at(reconnect_after_msec, try_number)`. If the number of tries
      exceeds the length of the list, the final value will be repeated.
      """,
      type: {:list, :non_neg_integer},
      default: [10, 50, 100, 150, 200, 250, 500, 1_000, 2_000, 5_000]
    ],
    rejoin_after_msec: [
      doc: """
      A list of times to reference for trying to rejoin a topic when
      `Slipstreamm.rejoin/0` is used. The msec time
      will be fetched based on its position in the list with
      `Enum.at(rejoin_after_msec, try_number)`. If the number of tries
      exceeds the length of the list, the final value will be repeated.
      """,
      type: {:list, :non_neg_integer},
      default: [100, 500, 1_000, 2_000, 5_000, 10_000]
    ]
  ]

  @moduledoc """
  Configuration for a Slipstream websocket connection

  #{NimbleOptions.docs(@definition)}

  Note that a Phoenix.Channel defined with

  ```elixir
  socket "/socket", UserSocket, ..
  ```

  Can be connected to at `/socket/websocket`.
  """

  defstruct Keyword.keys(@definition)

  @type t :: %__MODULE__{
          uri: %URI{},
          heartbeat_interval_msec: non_neg_integer(),
          headers: [{String.t(), String.t()}],
          json_parser: module(),
          reconnect_after_msec: [non_neg_integer()],
          rejoin_after_msec: [non_neg_integer()]
        }

  @known_protocols ~w[ws wss]

  @doc """
  Validates a proposed configuration
  """
  @doc since: "1.0.0"
  @spec validate(Keyword.t()) ::
          {:ok, t()} | {:error, %NimbleOptions.ValidationError{}}
  def validate(opts) do
    case NimbleOptions.validate(opts, @definition) do
      {:ok, validated} -> {:ok, struct(__MODULE__, validated)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates a proposed configuration, raising on error
  """
  @spec validate!(Keyword.t()) :: t()
  def validate!(opts) do
    validated = NimbleOptions.validate!(opts, @definition)
    struct(__MODULE__, validated)
  end

  @doc false
  def parse_uri(proposed_uri) do
    with true <- is_binary(proposed_uri),
         %URI{} = uri <- proposed_uri |> URI.parse() |> assume_port(),
         {:protocol, protocol} when protocol in @known_protocols <-
           {:protocol, uri.scheme},
         {:port, port} when is_integer(port) and port > 0 <- {:port, uri.port} do
      {:ok, uri}
    else
      {:port, bad_port} ->
        {:error,
         "unparseable port value #{inspect(bad_port)}: please provide a positive-integer value"}

      {:protocol, unknown_protocol} ->
        {:error,
         "unknown protocol #{inspect(unknown_protocol)}: only #{
           inspect(@known_protocols)
         } are accepted"}

      _unparsed_value ->
        {:error, "could not parse #{inspect(proposed_uri)} with URI.parse/1"}
    end
  end

  defp assume_port(%URI{scheme: "ws", port: nil} = uri),
    do: %URI{uri | port: 80}

  defp assume_port(%URI{scheme: "wss", port: nil} = uri),
    do: %URI{uri | port: 443}

  defp assume_port(uri), do: uri

  @doc false
  def parse_pair_of_strings({key, value})
      when is_binary(key) and is_binary(value) do
    {:ok, {key, value}}
  end

  def parse_pair_of_strings(unparsed) do
    {:error, "could not parse #{inspect(unparsed)} as a two-tuple of strings"}
  end
end
