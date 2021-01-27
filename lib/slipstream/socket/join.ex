defmodule Slipstream.Socket.Join do
  @moduledoc false

  # a datastructure representing a join configuration and the join's current
  # status

  defstruct ~w[topic params status rejoin_counter]a

  @type t :: %__MODULE__{
          status: :requested | :joined | :closed,
          topic: String.t(),
          params: Slipstream.json_serializable(),
          rejoin_counter: non_neg_integer()
        }

  def new(topic, params) do
    %__MODULE__{
      topic: topic,
      params: params,
      status: :requested,
      rejoin_counter: 0
    }
  end
end
