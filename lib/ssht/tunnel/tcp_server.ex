defmodule SSHt.Tunnel.TCPServer do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    {:ok, opts}
  end
end
