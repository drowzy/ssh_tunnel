defmodule SSHt.Tunnel do
  require Logger

  def start_link(%SSHt.Conn{} = ssh, opts) do
    DynamicSupervisor.start_child(SSHt.TunnelSupervisor, worker_spec(ssh, opts))
  end

  defp worker_spec(ssh, opts) do
    {_, port_or_path} = Keyword.get(opts, :from)
    {SSHt.Tunnel.TCPServer, Keyword.merge(opts, ssh: ssh, name: base_name(port_or_path))}
  end

  def base_name(port_or_path) do
    "#{__MODULE__}.#{port_or_path}" |> String.to_atom()
  end
end
