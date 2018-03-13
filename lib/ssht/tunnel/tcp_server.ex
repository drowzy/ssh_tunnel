defmodule SSHt.Tunnel.TCPServer do
  use GenServer
  require Logger

  alias SSHt.Tunnel.TCPHandler

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    from = {_, port} = Keyword.get(opts, :from)
    name = Keyword.get(opts, :name)
    to = Keyword.get(opts, :to)
    ssh = Keyword.get(opts, :ssh)

    {:open, ch} = SSHt.Conn.direct_tcpip(ssh, from, to)

    {:ok, pid} =
      :ranch.start_listener(
        name,
        :ranch_tcp,
        [{:port, port}],
        TCPHandler,
        Keyword.merge(opts, channel: ch)
      )

    Logger.info(fn -> "Starting server #{name}" end)

    {:ok, %{server: pid, name: name, ch: ch, ssh: ssh}}
  end
  end

  defp default_opts(opts) do
  end
end
