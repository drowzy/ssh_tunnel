defmodule SSHt do
  defdelegate connect(opts), to: SSHt.Conn
  defdelegate start_link(ssh, opts), to: SSHt.Tunnel
end
