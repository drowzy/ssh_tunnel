defmodule SSHt.Conn do
  defstruct host: nil, port: nil, conn: nil

  @direct_tcpip String.to_charlist("direct-tcpip")
  @stream_local String.to_charlist("direct-streamlocal@openssh.com")

  @ini_window_size 1024 * 1024
  @max_packet_size 32 * 1024

  def connect(opts \\ []) do
    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 22)
    ssh_config = defaults(opts)

    case :ssh.connect(String.to_charlist(host), port, ssh_config) do
      {:ok, conn} -> {:ok, %__MODULE__{host: host, port: port, conn: conn}}
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
