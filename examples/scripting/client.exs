import Slipstream
import Slipstream.Socket

socket = connect!(uri: "ws://localhost:4000/socket/websocket") |> await_connect!

topic = "rooms:lobby"
socket = join(socket, topic, %{"fizz" => "buzz"}) |> await_join!(topic)

_ref = push!(socket, topic, "quicksand", %{"a" => "b"})

{:ok, %{"pong" => "pong"}} = push!(socket, topic, "ping", %{}) |> await_reply!

push!(socket, topic, "push to me", %{})

await_message!(^topic, "foo", _payload)
