defmodule SSHt do
  @moduledoc """
  Module for creating forwarded SSH tunnels using erlang ssh
  ```
  {:ok, ssh} = SSHt.connect(host: "127.0.0.1", user: "user", password: "password")
  {:ok, pid} = SSHt.Tunnel.start_link(shh, {:tcpip, {3000, {"192.168.1.30", 80}}})
  ```
  """
  @direct_tcpip String.to_charlist("direct-tcpip")
  @stream_local String.to_charlist("direct-streamlocal@openssh.com")

  @ini_window_size 1024 * 1024
  @max_packet_size 32 * 1024

  @type location :: {String.t(), integer()}

  @doc """
  Create a connetion to a remote host with the provided options.
  """
  @spec connect(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def connect(opts \\ []) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 22)
    ssh_config = defaults(opts)

    :ssh.connect(String.to_charlist(host), port, ssh_config)
  end

  @spec direct_tcpip(pid(), location, location) :: {:ok, integer()} | {:error, term()}
  def direct_tcpip(ref, from, to) do
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
           ref,
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

  @spec stream_local_forward(pid(), String.t()) :: {:ok, integer()} | {:error, term()}
  def stream_local_forward(ref, socket_path) do
    msg = <<byte_size(socket_path)::size(32), socket_path::binary, 0::size(32), 0::size(32)>>

    case :ssh_connection_handler.open_channel(
           ref,
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
