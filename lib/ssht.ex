defmodule SSHt do
  @direct_tcpip String.to_charlist("direct-tcpip")
  @stream_local String.to_charlist("direct-streamlocal@openssh.com")

  @ini_window_size 1024 * 1024
  @max_packet_size 32 * 1024

  defdelegate start_link(ref, to), to: SSHt.Tunnel

  def connect(opts \\ []) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 22)
    ssh_config = defaults(opts)

    :ssh.connect(String.to_charlist(host), port, ssh_config)
  end

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

    :ssh_connection_handler.open_channel(
      ref,
      @direct_tcpip,
      msg,
      @ini_window_size,
      @max_packet_size,
      :infinity
    )
  end

  def stream_local_forward(ref, socket_path, _opts \\ []) do
    msg = <<byte_size(socket_path)::size(32), socket_path::binary, 0::size(32), 0::size(32)>>

    :ssh_connection_handler.open_channel(
      ref,
      @stream_local,
      msg,
      @ini_window_size,
      @max_packet_size,
      :infinity
    )
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
