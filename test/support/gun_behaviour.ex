defmodule GunBehaviour do
  @moduledoc false

  @callback open(
              host :: :inet.hostname(),
              port :: :inet.port_number(),
              opts :: map()
            ) ::
              {:ok, conn :: pid()}

  @callback ws_upgrade(
              conn :: pid(),
              path :: charlist(),
              headers :: [{binary(), binary()}],
              opts :: map()
            ) :: reference()

  @callback ws_send(conn :: pid, frame) :: :ok
            when frame:
                   :close
                   | :ping
                   | :pong
                   | {:text | :binary | :close | :ping | :pong, iodata()}
                   | {:close, non_neg_integer(), iodata()}

  @callback close(conn :: pid()) :: :ok
end
