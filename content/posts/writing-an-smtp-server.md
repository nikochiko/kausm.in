---
title: "Writing an SMTP Server from Scratch (WIP)"
date: 2022-02-14T18:31:11+05:30
draft: false
---

A few months ago, I wrote an SMTP server from scratch to learn about the protocol. It soon came to me that the knowledge of
SMTP internals is not as common as it should be. Upon not finding a satisfactory blog on the topic, I read through the RFCs
and tried to create my own server. I am writing this blog as a relatively concise summary of that.

Before we go on to writing our server, I want to give some context that should be treated as a prerequisite.

SMTP is the protocol that is used to send and receive emails (as the name suggest, Simple Mail *Transfer* Protocol). When a
mail is sent by a user, it is handed over to an SMTP server to pass it on to its destination, which is a receiving SMTP
server. Once the mail reaches its destination SMTP server, other protocols such as IMAP or POP3 take over and store the
emails so that they can be retrieved by the receiving user at a later point.

SMTP uses stateful, long-lasting TCP connections where the client and server send data back and forth.
The client can even send multiple emails on the same connection. This is in contrast to HTTP 1, where client asks for
exactly one resource and the server sends back just that before the connection is closed.

The SMTP specification defines some commands that the client can use to set the headers and content. The client will send
these commands in their specified format with arguments, and the server will respond with a response code that the client
can understand. Optionally, the server can send some human-readable data that may be useful for debugging.

These are some of the basic commands that all SMTP servers should support:
- **HELO**: Hello
    - Once the TCP connection is established, this is always the first command that the client should send. By this command,
    the client identifies itself with a domain name (an FQDN - fully qualified domain name)
    - Syntax: `HELO kausm.in`
- **MAIL FROM**: I want to send an email, and this email is from ...
    - This starts a mail transaction (*I want to send a mail*), and specifies the sender address (*and this email is from*).
    - Syntax: `MAIL FROM: sender@kausm.in`
- **RCPT TO**: A recipient of this email is ...
    - This is used to specify a recipient of this mail. If a client wants to send a mail to multiple receiving addresses,
    it should run this command multiple times with each of the receiving email addresses.
    - Syntax: `RCPT TO: receiver@kausm.in`
- **DATA**: My mail data is ...
    - Starts the actual mail data. Once this command is run and an OK response is received from the server, the client should
    go on to send first the email headers and the email content as text. The delimiter to end this text is `<CRLF>.<CRLF>`.
    - Headers can be specified like `Date: Mon, 14 February 2022 20:40:34`, `Reply-To: kaustubh@kausm.in`, etc. separated by newlines
    - Syntax:
        - Client: `DATA`
        - Server: `250 OK`
        - Client:
        ```
        Date: Mon, 14 February 2022 20:40:34
        From: sender@kausm.in
        To: receiver@kausm.in
        Subject: Hello Receiver
        Reply-To: kaustubh@kausm.in

        Hey there

        .

        ```
- **QUIT**: That's all I wanted to do, thanks for your service.
    - This tells the server that its work is done and that the server can now close the connection.
    - Note that the SMTP specification explicitly mentions that the server shoudln't close the connection abruptly unless the
    client executes this command. Even after you complete a mail transaction, this gives you the option to send addiotional
    mails over the same connection.
    - Syntax: `QUIT`

There are some more commands that can be used once the client and server agree that both support that command. For example,
the `LOGIN` command for authentication and `STARTTLS` for encryption. These are extensions that do not *have* to be implemented
by all SMTP servers, but are practically required to go past the security/spam filters of sophisticated receiving servers.
The functionality of these commands can be agreed upon by using an `EHLO` (*Extended Hello*) command instead of the usual
`HELO` command, which the server responds to with a list of supported extensions.

**OK, let's start.**

Here's what we need to do:
1. Write a server that can accept and read from TCP connections.
2. Support the `HELO` command.
3. Support `MAIL FROM`.
4. Support `RCPT TO`.
5. Support `DATA`.

#### 1. Writing a TCP server

```go
1   package main
2   
3   import (
4-7      ...
8   )
9   
10  const HOST = "localhost"
11  const PORT = 3333
```

Initialize a listener on the host and port, and accept connections on it. See Go standard documentation of the
[net](https://pkg.go.dev/net) pkg for more information.

```go
13  func main() {
14  	// for now, we'll just listen on localhost:3333
15  	listenAddr := fmt.Sprintf("%s:%d", HOST, PORT)
16  
17  	listener, err := net.Listen("tcp", listenAddr)
18  	if err != nil {
19  		// for now, just panic with the error
20  		panic(err)
21  	}
22  
23  	// accept connections forever
24  	for {
25  		conn, err := listener.Accept()
26  		if err != nil {
27  			// simply log the error for now, and continue listening
28  			log.Printf("error while accepting conn: %v\n", err)
29  		} else {
30  			go handleConnection(conn)
31  		}
32  	}
33  }
```

In `handleConnection`, we'll first read from the connection into a buffer and then write that back into the connection.

```go
35  func handleConnection(conn net.Conn) {
36  	defer func() {
37  		conn.Close()
38  	}()
39  
40  	// we'll be keeping the data here
41  	buffer := make([]byte, 1024)
42  
43  	// read into a buffer
44  	n, err := conn.Read(buffer)
45  	if err != nil {
46  		log.Printf("error while reading from connection: %v\n", err)
47  		return
48  	}
49  
50  	newlyRead := string(buffer[:n])
51      log.Printf("Got input from client: '%s'. Echoing it back now\n", newlyRead)
52  
53  	// now just echo it back with a prefix
54  	_, err = conn.Write([]byte("Server says: " + newlyRead))
55  	if err != nil {
56  		log.Printf("error while writing to connection: %v\n", err)
57  		return
58  	}
59  }
```

Now we can test out the server with [netcat](https://linuxize.com/post/netcat-nc-command-with-examples/).

```bash
$ # save the Go code in a main.go file and run this in one terminal
$ go run main.go

$ # in another terminal, start netcat and connect to our server
$ nc localhost 3333
Hello there. This will be echoed back
Server says: Hello there. This will be echoed back

```

Great, we now have our TCP listener. We can get started with the SMTP commands.

#### 2. Supporting SMTP commands

To support different commands, we need to read and parse the line input by the client. Let's make a list of what we'll
need to do:
- Parse the text - split it into command and arguments
- If the command is a valid command, pass the `conn` object to its handler until it finishes its job and returns it
back.
- Sometimes, we need certain prerequisite data from commands before we can start executing other commands. For example,
the client has to send the `HELO`/`EHLO` command before being able to send any other command, the `MAIL FROM` needs to be
run before `RCPT TO` is run, and so on. For this reason, we have to keep state of what data we have received from the
client.

##### The `HELO` command

```go

```

----------

1. _RFCs: RFC 883, etc._
