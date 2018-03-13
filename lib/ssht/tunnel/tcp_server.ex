defmodule SSHt.Tunnel.TCPServer do
  use GenServer
  require Logger

  alias SSHt.Tunnel.TCPHandler

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, args)
  end

  def init(args) do
    name = Keyword.get(args, :name)
    {_, port} = Keyword.get(args, :from)
    opts = [{:port, port}]

    {:ok, pid} = :ranch.start_listener(name, :ranch_tcp, opts, TCPHandler, [])

    Logger.info(fn -> "Starting server #{name}" end)

    {:ok, pid}
  end

  defp default_opts(opts) do
  end
end
