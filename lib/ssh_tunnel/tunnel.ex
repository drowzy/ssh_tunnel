defmodule SSHTunnel.Tunnel do
  @type to :: {:tcpip | :local, tuple()}

  @spec start(pid(), to) :: {:ok, pid()} | {:error, term()}
  def start(ref, to) do
    DynamicSupervisor.start_child(
      SSHTunnel.TunnelSupervisor,
      worker_spec(worker_opts(ref, to))
    )
  end

  defp worker_spec(opts) do
    name = Keyword.get(opts, :name)

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

  defp worker_opts(ref, {_type, {port_or_path, _}} = to),
    do: basic_opts(ref, base_name(port_or_path), to)

  defp basic_opts(ref, name, target) do
    Keyword.new()
    |> Keyword.put(:name, name)
    |> Keyword.put(:ssh_ref, ref)
    |> Keyword.put(:target, target)
  end

  defp base_name(port_or_path) do
    "#{__MODULE__}.#{port_or_path}" |> String.to_atom()
  end
end
