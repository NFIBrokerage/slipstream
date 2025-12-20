# Token Refresh

Often times, the socket server you want to connect to requires some form
of token authentication. Sometimes these tokens expire and need to be
refreshed before a reconnect happens. The `Slipstream.refresh_connection_config/2` callback is there to make it easy to update connection configuration before reconnecting.

## Tutorial

In this tutorial, we'll build a basic Slipstream client that can handle
refresh a disconnection from our websocket and reconnect successfully.

Let's begin with a fresh client

```elixir
defmodule MyApp.TokenRefreshClient do
  use Slipstream

  def start_link(opts) do
    Slipstream.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Slipstream
  def init(opts) do
    {:ok, connect!(opts)}
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    reconnect(socket)
  end
end
```

Notice that we simply `reconnect/2` inside of the `handle_disconnect/2`
callback.

Now that we know when a token needs to be refreshed, let's add in the callback to our client.

```elixir
@impl Slipstream
def refresh_connection_config(_socket, config) do
  update_uri(config)
end

defp update_uri(config) do
  uri =
    config
    |> Keyword.get(:uri)
    |> URI.parse()
    |> Map.put(:query, "token=#{make_new_token()}")
    |> URI.to_string()

  Keyword.put(config, :uri, uri)
end

defp make_new_token(), do: "get_new_token_here"
```

The `config` on the socket can be unwrapped with the `URI` module. Then, we
simply append our token onto the query and change it back into a string.
This gives us a clean API to ensure our connections always contain a token.
Let's update our `init/1` to use this new function:

```elixir
def init(config) do
  config = update_uri(config)

  new_socket()
  |> assign(:config, config)
  |> connect(config)
end
```

Now, when we connect for the first time or when we fail to connect due to a 403,
our client will automatically refresh the token and connect again!

See
[`examples/token_refresh/client.ex`](https://github.com/NFIBrokerage/slipstream/blob/main/examples/token_refresh/client.ex)
for the full code of this example client.
