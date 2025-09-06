defmodule Slipstream.BinaryRepliesTest do
  use Slipstream.SocketTest
  @moduletag :capture_log

  defmodule Client do
    use Slipstream
    @topic "rooms:lobby"

    def start_link(opts), do: Slipstream.start_link(__MODULE__, opts)

    @impl Slipstream
    def init(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      connect_opts = Keyword.drop(opts, [:test_pid])

      socket =
        connect!(connect_opts)
        |> assign(:test_pid, test_pid)

      {:ok, socket}
    end

    @impl Slipstream
    def handle_connect(socket) do
      {:ok, Slipstream.join(socket, @topic, %{})}
    end

    @impl Slipstream
    def handle_join(@topic, _resp, socket) do
      {:ok, ref} = Slipstream.push(socket, @topic, "needs-binary", %{})
      {:noreply, assign(socket, :ref, ref)}
    end

    @impl Slipstream
    def handle_reply(
          ref,
          payload,
          %{assigns: %{ref: ref, test_pid: pid}} = socket
        ) do
      send(pid, {:binary_reply, payload})
      {:ok, socket}
    end
  end

  test "handle_reply/3 receives binary payload unchanged" do
    client =
      start_supervised!(
        {Client,
         uri: "wss://example.invalid", test_mode?: true, test_pid: self()}
      )

    # macro itself «connect» and confirm join
    connect_and_assert_join(client, "rooms:lobby", %{}, :ok)

    # client itself makes push in handle_join — catch it and take ref
    assert_push "rooms:lobby", "needs-binary", %{}, ref

    bin = <<0, 1, 2, 3, 255>>
    # emulate server answer as binary
    Slipstream.SocketTest.reply(client, ref, {:ok, bin})

    # make sure client received exactly binary without any transformations
    assert_receive {:binary_reply, {:ok, ^bin}}
  end
end
