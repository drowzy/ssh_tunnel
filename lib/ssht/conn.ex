defmodule SSHt.Conn do
  defstruct host: nil, port: nil, conn: nil

  @direct_tcpip String.to_charlist("direct-tcpip")

  def connect(opts \\ []) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 22)
    ssh_config = defaults(opts)

    case :ssh.connect(String.to_charlist(host), port, ssh_config) do
      {:ok, conn} -> {:ok, %__MODULE__{host: host, port: port, conn: conn}}
      {:error, reason} -> {:error, reason}
    end
  end

  def direct_tcpip(%__MODULE__{conn: conn}, from, to) do
    {orig_host, orig_port} = from
    {remote_host, remote_port} = to

    # Need to prepend the size of hostname fields
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

    :ssh_connection_handler.open_channel(conn, @direct_tcpip, msg, 1024 * 1024, 32 * 1024, 5000)
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
