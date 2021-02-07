# Repeater Client

We call any client that repeats messages from another service's endpoint a
_repeater_ client.

This is a useful pattern when one wishes to ferry messages (without changing
them) from one service to another when the services are different, or when
the services are the same but endpoint clustering is not possible/desired.

In order to make this happen, we will create a client that

- connects to the remove service
- subscribes to the topic we wish to repeat
- broadcasts messages as they happen to this service's endpoint

## Tutorial
