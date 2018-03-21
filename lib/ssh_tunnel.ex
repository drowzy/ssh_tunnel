defmodule SSHTunnel do
  @moduledoc ~S"""
  Module for creating SSH tunnels using `:ssh`.

  It provides functions to create forwarded ssh channels, similair
  to how other channels can be created using `:ssh_connection`.

  There are two type of channels supported
  * `directtcp-ip` - Forwards a port from the client machine to the remote machine. This is the same as `ssh -nNT -L 8080:forward.example.com:9000 user@sshserver.example.com`
  * `direct-streamlocal` - Forwards to a unix domain socket. This is the same as `ssh -nNT -L 8080:/var/lib/mysql/mysql.sock user@sshserver.example.com`

  When using `direct_tcpip/3` or `stream_local_forward/2` directly there will not be any local port or socket bound,
  this can either be done using `SSHTunnel.Tunnel` or by manually sending data with `:ssh_connection.send/3`

  Although `connect/1` can be used to connect to the remote host, other methods are supported.
  One can use [SSHex](https://github.com/rubencaro/sshex), `:ssh.connect/3` for instance.

  ## Tunnels

  Tunnels are on-demand TCP servers and are bound listeners to either a port or a path. The tunnel will handle
  relaying TCP messages to the ssh connection and back.

  ## Examples

      {:ok, ssh_ref} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")
      {:ok, pid} = SSHTunnel.start_tunnel(pid, {:tcpip, {8080, {"192.168.90.15", 80}}})
      # Send a TCP message for instance HTTP
      %HTTPoison.Response{body: body} = HTTPoison.get!("127.0.0.1:8080")
      IO.puts("Received body: #{body})

  """

  @direct_tcpip String.to_charlist("direct-tcpip")
  @stream_local String.to_charlist("direct-streamlocal@openssh.com")

  @ini_window_size 1024 * 1024
  @max_packet_size 32 * 1024

  @type location :: {String.t(), integer()}

  @doc """
  Create a connetion to a remote host with the provided options. This function is mostly used as
  convenience wrapper around `:ssh_connect/3` and does not support all options.

  returns: `{:ok, connection}` or `{:error, reason}`.
  """
  @spec connect(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def connect(opts \\ []) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 22)
    ssh_config = defaults(opts)

    :ssh.connect(String.to_charlist(host), port, ssh_config)
  end

  @doc ~S"""
  Starts a SSHTunnel.Tunnel process, the tunnel will listen to either a local port or local path and handle
  passing messages between the TCP client and ssh connection.

  ## Examples

      {:ok, ssh_ref} = SSHTunnel.connect(host: "sshserver.example.com", user: "user", password: "password")
      {:ok, pid} = SSHTunnel.start_tunnel(pid, {:tcpip, {8080, {"192.168.90.15", 80}}})
      # Send a TCP message
      %HTTPoison.Response{body: body} = HTTPoison.get!("127.0.0.1:8080")
      IO.puts("Received body: #{body})

  """
  @spec start_tunnel(pid(), SSHTunnel.Tunnel.to()) :: {:ok, pid()} | {:error, term()}
  defdelegate start_tunnel(pid, to), to: SSHTunnel.Tunnel, as: :start

  @doc ~S"""
  Creates a ssh directtcp-ip forwarded channel to a remote port.
  The returned channel together with a ssh connection reference (returned from `:ssh.connect/4`) can be used
  to send messages with `:ssh_connection.send/3`

  returns: `{:ok, channel}` or `{:error, reason}`.

  ## Examples:

      msg = "GET / HTTP/1.1\r\nHost: localhost:8080\r\nUser-Agent: curl/7.47.0\r\nAccept: */*\r\n\r\n"

      {:ok, pid} = SSHTunnel.connect(host: "192.168.1.10", user: "user", password: "password")
      {:ok, ch} = SSHTunnel.direct_tcpip(pid, {"127.0.0.1", 8080}, {"192.168.1.10", 80})
      :ok = :ssh_connection.send(pid, ch, msg)
      recieve do
        {:ssh_cm, _, {:data, channel, _, data}} -> IO.puts("Data: #{(data)}")
      end

  """
  @spec direct_tcpip(pid(), location, location) :: {:ok, integer()} | {:error, term()}
  def direct_tcpip(pid, from, to) do
    {orig_host, orig_port} = from
    {remote_host, remote_port} = to

    remote_len = byte_size(remote_host)
    orig_len = byte_size(orig_host)

    msg = <<
      remote_len::size(32),
      remote_host::binary,
      remote_port::size(32),
      orig_len::size(32),
      orig_host::binary,
      orig_port::size(32)
    >>

    open_channel(pid, @direct_tcpip, msg, @ini_window_size, @max_packet_size, :infinity)
  end

  @doc ~S"""
  Creates a ssh stream local-forward channel to a remote unix domain socket.

  The returned channel together with a ssh connection reference (returned from `:ssh.connect/4`) can be used
  to send messages with `:ssh_connection.send/3`.

  returns: `{:ok, channel}` or `{:error, reason}`.

  Ex:
  ```
  msg = "GET /images/json HTTP/1.1\r\nHost: /var/run/docker.sock\r\nAccept: */*\r\n\r\n"

  {:ok, pid} = SSHTunnel.connect(host: "192.168.90.15", user: "user", password: "password")
  {:ok, ch} = SSHTunnel.stream_local_forward(pid, "/var/run/docker.sock")
  :ok = :ssh_connection.send(pid, ch, msg)
  ```
  """
  @spec stream_local_forward(pid(), String.t()) :: {:ok, integer()} | {:error, term()}
  def stream_local_forward(pid, socket_path) do
    msg = <<byte_size(socket_path)::size(32), socket_path::binary, 0::size(32), 0::size(32)>>

    open_channel(pid, @stream_local, msg, @ini_window_size, @max_packet_size, :infinity)
  end

  defp open_channel(pid, type, msg, window_size, max_packet_size, timeout) do
    case :ssh_connection_handler.open_channel(
           pid,
           type,
           msg,
           window_size,
           max_packet_size,
           timeout
         ) do
      {:open, ch} -> {:ok, ch}
      {:open_error, _, reason, _} -> {:error, to_string(reason)}
    end
  end

  defp defaults(opts) do
    user = Keyword.get(opts, :user, "")
    password = Keyword.get(opts, :password, "")

    [
      user_interaction: false,
      silently_accept_hosts: true,
      user: String.to_charlist(user),
      password: String.to_charlist(password)
    ]
  end
end
