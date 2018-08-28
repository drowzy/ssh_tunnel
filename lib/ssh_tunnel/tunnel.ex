defmodule SSHTunnel.Tunnel do
  @type to :: {:tcpip | :local, tuple()}

  @spec start(pid(), to, Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start(ref, to, opts \\ []) do
    worker_opts =
      ref
      |> worker_opts(to)
      |> Keyword.merge(opts)
      |> worker_spec()

    DynamicSupervisor.start_child(SSHTunnel.TunnelSupervisor, worker_opts)
  end

  @spec stop(pid()) :: :ok | :error
  def stop(pid) do
    DynamicSupervisor.terminate_child(SSHTunnel.TunnelSupervisor, pid)
  end

  defp worker_spec(opts) do
    name = Keyword.get(opts, :name, make_ref())

    ranch_opts =
      case Keyword.get(opts, :target) do
        {:local, {path, _}} -> [ip: {:local, path}, port: 0]
        {:tcpip, {port, _}} -> [port: port]
      end

    :ranch.child_spec(
      name,
      100,
      :ranch_tcp,
      ranch_opts,
      SSHTunnel.Tunnel.TCPHandler,
      opts
    )
  end

  defp worker_opts(ref, target) do
    Keyword.new()
    |> Keyword.put(:ssh_ref, ref)
    |> Keyword.put(:target, target)
  end
end
