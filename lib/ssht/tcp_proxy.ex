defmodule SSHt.TcpProxy do
  @moduledoc """
  """

  @default_opts [:binary, active: false, reuseaddr: true, packet: 0]

  def listen(path, :unix) do
    opts = @default_opts ++ [ifaddr: {:local, socket_path(path)}]
    :gen_tcp.listen(0, opts)
  end

  def listen(port, :tcpip), do: :gen_tcp.listen(port, @default_opts)

  def accept(socket, callback) do
    {:ok, client_socket} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(SSHt.TaskSupervisor, fn ->
        handle_connection(client_socket, callback)
      end)

    :ok = :gen_tcp.controlling_process(client_socket, pid)

    client_socket
  end

  def close(socket), do: :gen_tcp.close(socket)
  def send_msg(socket, data), do: :gen_tcp.send(socket, data)

  defp handle_connection(socket, callback) do
    case :gen_tcp.recv(socket, 0) do
      {:error, :closed} ->
        :ok

      {:ok, data} ->
        callback.(data)
        handle_connection(socket, callback)
    end
  end

  defp socket_path(path), do: String.to_charlist(path)
end
