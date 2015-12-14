# Diaspora Personal Messenger
### The federation interacting tool

This is a local CLI interactive tool that interacts with the Diaspora federation.

It is useful in debugging of federation issues. Also, it may act as a communication tool for paranoics, because it allows (with proper configuration) to communicate in the federation  using encrypted messages without storing your private keys at a third party.

## Usage
From the checked out source run:
```
  bundle exec ruby app.rb 
```
This will give you an interactive console.

Set your hostname so it is visible to the pod you want to communicate:
```
  set_myhost "example.com"
```

Create a local user:
```
  create_user "ivan"
```

Send sharing request:
```
  send_request "hq@pod.diaspora.software"
```

Send a message (a conversation, actually):
```
  send_message "hq@pod.diaspora.software", "yo, bro <3"
```

Quit with command:
```
  quit
```
