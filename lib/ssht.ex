defmodule SSHt do
  @moduledoc ~S"""
  Module for creating forwarded SSH tunnels using `:ssh`.
  This package is contains two modules of importance the first one is this one. Which allows you to connect to ssh server
  and create the desired channels.

  There are two type of channels
  * `directtcp-ip` - Connect to a <remote_ip>:<port>
  * `direct-streamlocal` - Connect to a unix domain socket

  ## SSHt.Tunnel
  This module allows creation of on-demand TCP tunnels to forward messages. The tunnels will create the required channels
  and start a TCP server on the desired port (or path) and relay messages to the ssh connection.

  Ex:
  ```elixir
  {:ok, ssh_ref} = SSHt.connect(host: "192.168.90.15", user: "ubuntu", password: "")
  {:ok, pid} = SSHt.Tunnel.start_link(pid, {:tcpip, {8080, {"192.168.90.15", 80}}})
  # Send a TCP message for instance HTTP
  %HTTPoison.Response{body: body} = HTTPoison.get!("127.0.0.1:8080")
  IO.puts("Received body: #{body})
  ```
  """
  @direct_tcpip String.to_charlist("direct-tcpip")
  @stream_local String.to_charlist("direct-streamlocal@openssh.com")

  @ini_window_size 1024 * 1024
  @max_packet_size 32 * 1024

  @type location :: {String.t(), integer()}

  @doc """
  Create a connetion to a remote host with the provided options. This function is mostly used as
  convenience wrapper around :ssh_connect/3 and does not support all options.

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
  Creates a ssh directtcp-ip forwarded tunnel to a remote port.
  The returned channel together with a ssh connection reference (returned from `:ssh.connect/4`) can be used
  to send messages with `:ssh_connection.send/3`

  returns: `{:ok, channel}` or `{:error, reason}`.

  #### Examples:
  ```
  msg = "GET / HTTP/1.1\r\nHost: localhost:8080\r\nUser-Agent: curl/7.47.0\r\nAccept: */*\r\n\r\n"

  {:ok, pid} = SSHt.connect(host: "192.168.1.10", user: "user", password: "password")
  {:ok, ch} = SSHt.direct_tcpip(pid, {"127.0.0.1", 8080}, {"192.168.1.10", 80})
  :ok = :ssh_connection.send(pid, ch, msg)
  recieve do
    {:ssh_cm, _, {:data, channel, _, data}} -> IO.puts("Data: #{(data)}")
  end
  ```
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

    case :ssh_connection_handler.open_channel(
           pid,
           @direct_tcpip,
           msg,
           @ini_window_size,
           @max_packet_size,
           :infinity
         ) do
      {:open, ch} -> {:ok, ch}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc ~S"""
  Creates a ssh stream local-forward channel to a remote unix domain socket.

  The returned channel together with a ssh connection reference (returned from `:ssh.connect/4`) can be used
  to send messages with `:ssh_connection.send/3`.

  returns: `{:ok, channel}` or `{:error, reason}`.

  Ex:
  ```
  msg = "GET /images/json HTTP/1.1\r\nHost: /var/run/docker.sock\r\nAccept: */*\r\n\r\n"

  {:ok, pid} = SSHt.connect(host: "192.168.90.15", user: "user", password: "password")
  {:ok, ch} = SSHt.stream_local_forward(pid, "/var/run/docker.sock")
  :ok = :ssh_connection.send()
  ```
  """
  @spec stream_local_forward(pid(), String.t()) :: {:ok, integer()} | {:error, term()}
  def stream_local_forward(pid, socket_path) do
    msg = <<byte_size(socket_path)::size(32), socket_path::binary, 0::size(32), 0::size(32)>>

    case :ssh_connection_handler.open_channel(
           pid,
           @stream_local,
           msg,
           @ini_window_size,
           @max_packet_size,
           :infinity
         ) do
      {:open, ch} -> {:ok, ch}
      {:error, reason} -> {:error, reason}
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
