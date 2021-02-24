defmodule Slipstream.Message do
  @moduledoc false

  @type t :: %__MODULE__{
          topic: String.t(),
          event: String.t(),
          payload: term(),
          ref: String.t() | nil,
          join_ref: String.t() | nil
        }

  defstruct ~w[topic event payload ref join_ref]a

  # a wrapper around Phoenix.Socket.Message
  # represents a message sent from the remote websocket server

  @spec from_map!(%{String.t() => term()}) :: t()
  def from_map!(map) when is_map(map) do
    %__MODULE__{
      topic: Map.fetch!(map, "topic"),
      event: Map.fetch!(map, "event"),
      payload: Map.fetch!(map, "payload"),
      ref: Map.fetch!(map, "ref"),
      join_ref: Map.get(map, "join_ref")
    }
  end
end
