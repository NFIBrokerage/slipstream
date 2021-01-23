defmodule SlipstreamWeb.Router do
  use SlipstreamWeb, :router

  @moduledoc false

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", SlipstreamWeb do
    pipe_through(:api)
  end
end
