defmodule SSHt.Tunnel.TCPServer do
  use GenServer
  require Logger

  alias SSHt.Tunnel.TCPHandler

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    name = Keyword.get(opts, :name, "#{__MODULE__}")
    ssh = Keyword.get(opts, :ssh_ref)
    handler = Keyword.get(opts, :handler, TCPHandler)

    ranch_opts =
      case Keyword.get(opts, :target) do
        {:local, path} -> [{:local, path}]
        {:tcpip, {port, _}} -> [{:port, port}]
      end

    {:ok, pid} =
      :ranch.start_listener(
        name,
        :ranch_tcp,
        ranch_opts,
        handler,
        opts
      )

    Logger.info(fn -> "Starting server #{name}" end)

    {:ok, %{server: pid, name: name, ssh: ssh}}
  end

  def handle_info({:ssh_cm, _pid, {:data, _channel, _, _message}} = msg, %{name: name} = state) do
    name
    |> :ranch.procs(:connections)
    |> Enum.each(&send(&1, msg))

    Logger.debug(fn -> "Received SSH event #{inspect(msg)}" end)
    {:noreply, state}
  end
end
