defmodule SSHt.Tunnel do
  require Logger

  def start_link(ref, to) do
    DynamicSupervisor.start_child(
      SSHt.TunnelSupervisor,
      {SSHt.Tunnel.TCPServer, worker_opts(ref, to)}
    )
  end

  defp worker_opts(ref, {:tcpip, {port, _}} = to), do: basic_opts(ref, base_name(port), to)

  defp worker_opts(ref, {:local, socket_path} = to),
    do: basic_opts(ref, base_name(socket_path), to)

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
