defmodule SSHt.Tunnel do
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_child(SSHt.TunnelSupervisor, SSHt.Tunnel.TCPServer)
  end

  defp worker_spec(opts) do
    {SSHt.Tunnel.TCPServer, Keyword.merge(opts, name: base_name(8080))}
  end

  def base_name(port_or_path) do
    "#{__MODULE__}.#{port_or_path}" |> String.to_atom()
  end
end
