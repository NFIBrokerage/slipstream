defmodule Slipstream.TelemetryHelper do
  @moduledoc false
  @moduledoc since: "0.4.0"

  @doc since: "0.4.0"
  def id(length \\ 16) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
    |> binary_part(0, length)
    |> String.downcase()
  end

  @doc since: "0.4.0"
  def trace_id, do: id(32)
end
