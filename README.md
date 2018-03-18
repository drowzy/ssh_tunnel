# SSHTunnel

Create SSH tunnels in Elixir

[Documentation for SSHTunnel is available online.](https://hexdocs.pm/ssh_tunnel)

## Installation

Add SSHTunnel to your `mix.exs` and run `mix deps.get`

```elixir
def deps do
  [
    {:ssh_tunnel, "~> 0.1.0"}
  ]
end
```

## Usage

SSHTunnel can be used to create forwarded SSH channels, similair to channels created using `:ssh_connection`.
Sending messages can be done using `:ssh_connection.send/3`.

SSHTunnel also provide on-demand created tunnels, this is eqvivalent to using `ssh -nNT -L 8080:sshserver.example.com:80 user@sshserver.example.com`.
The tunnel process will forward messages from a TCP client to a ssh connection and back.

### As channels

* `directtcp-ip`

```elixir
msg = "GET / HTTP/1.1\r\nHost: localhost:8080\r\nUser-Agent: ssht/0.1.0\r\nAccept: */*\r\n\r\n"

{:ok, pid} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")
{:ok, ch} = SSHTunnel.direct_tcpip(pid, {"127.0.0.1", 8080}, {"sshserver.example.com", 80})
:ok = :ssh_connection.send(pid, ch, msg)
receive do
  {:ssh_cm, _, {:data, channel, _, data}} -> IO.puts("Data: #{(data)}")
end
```

* `streamlocal forward`

```elixir
msg = "GET /images/json HTTP/1.1\r\nHost: /var/run/docker.sock\r\nAccept: */*\r\n\r\n"

{:ok, pid} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")
{:ok, ch} = SSHTunnel.stream_local_forward(pid, "/var/run/docker.sock")
:ok = :ssh_connection.send(pid, ch, msg)

receive do
  {:ssh_cm, _, {:data, channel, _, data}} -> IO.puts("Data: #{(data)}")
end
```

### Tunnels

* `directtcp-ip`

```elixir
{:ok, ssh_ref} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")

# Will start a tcp server listening on port 8080.
# Any TCP messages received on `127.0.0.1:8080` will be forwarded to `sshserver.example.com:80`
{:ok, pid} = SSHTunnel.start_tunnel(pid, {:tcpip, {8080, {"sshserver.example.com", 80}}})

# Send a TCP message
%HTTPoison.Response{body: body} = HTTPoison.get!("127.0.0.1:8080")
IO.puts("Received body: #{body})
```

* `streamlocal forward`

```elixir
{:ok, ssh_ref} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")

# Will start a tcp server listening on the provided path.
# Any TCP messages received on `/path/to/socket.socket` will be forwarded to the `/path/`to/remote.sock` on sshserver.example.com
{:ok, pid} = SSHTunnel.start_tunnel(pid, {:local, {"/path/to/socket.sock", {"sshserver.example.com", "/path/to/remote.sock"}}})

# Send a TCP message
%HTTPoison.Response{body: body} = HTTPoison.get!("http+unix://#{URI.encode_www_form("/path/to/socket.sock")}")
IO.puts("Received body: #{body})
```

It is also possible to mix and match:

```elixir
# From a local port to a remote socket
{:ok, pid} = SSHTunnel.start_tunnel(pid, {:tcpip, {8080, {"sshserver.example.com", "/path/to/remote.sock"}}})

# From a local socket to a remote port
{:ok, pid} = SSHTunnel.start_tunnel(pid, {:local, {"/path/to/socket.sock", {"sshserver.example.com", 80}}})
```

## Testing

```bash
mix test
```
