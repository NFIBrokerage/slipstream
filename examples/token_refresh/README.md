# Token Refresh

Often times, the socket server you want to connect to requires some form
of token authentication. Sometimes these tokens expire and need to be
refreshed before a reconnect happens. `Slipstream.connect/2` is helpful
to use in place of `Slipstream.reconnect/1` if you need to modify your
connection configuration before reconnecting.

## Tutorial

In this tutorial, we'll build a basic Slipstream client that can handle
a 403 from our websocket and reconnect successfully.

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
callback. This is the perfect place to handle an expired token. The 
`reason` value will contain information about why we disconnected. In
this case, we're looking for a Mint error with a `403` status code. The 
error will roughly look like this:

```elixir
{:error, {_upgrade_failure, %{status_code: 403}}}
```

Let's update our `handle_disconnect/2` callback to handle that situation.

```elixir
@impl Slipstream
def handle_disconnect({:error, {_, %{status_code: 403}}}, socket) do
  # get new token and then attempt to reconnect
end
```

Now that we know when a token needs to be refreshed, let's add in some
basic token logic to our client. First, we'll wrap `connect/2` with a
custom function that retrieves a token and modifies our config:

```elixir
defp make_new_token, do: "your_token_logic"

defp connect_with_token(socket) do
  new_token = make_new_token()

  socket =
    update(socket, :config, fn config ->
      uri =
        config
        |> Keyword.get(:uri)
        |> URI.parse()
        |> Map.put(:query, "token=#{new_token}")
        |> URI.to_string()

      Keyword.put(config, :uri, uri)
    end)

  connect(socket, socket.assigns.config)
end
```

The `config` on the socket can be unwrapped with the `URI` module. Then, we
simply append our token onto the query and change it back into a string.
This gives us a clean API to ensure our connections always contain a token.
Let's update our `init/1` and `handle_disconnect/2` callbacks to use this
new function:

```elixir
def init(config) do
  new_socket()
  |> assign(:config, config)
  |> connect_with_token()
end

@impl Slipstream
def handle_disconnect({:error, {_, %{status_code: 403}}}, socket) do
  connect_with_token(socket)
end

@impl Slipstream
def handle_disconnect(_reason, socket) do
  reconnect(socket)
end
```

Now, when we connect for the first time or when we fail to connect due to a 403,
our client will automatically refresh the token and connect again!

See
[`examples/token_refresh/client.ex`](https://github.com/NFIBrokerage/slipstream/blob/main/examples/token_refresh/client.ex)
for the full code of this example client.
