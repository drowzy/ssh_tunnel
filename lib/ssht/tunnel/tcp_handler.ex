defmodule SSHt.Tunnel.TCPHandler do
  use GenServer
  require Logger

  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [{ref, socket, transport}])
    {:ok, pid}
  end

  def init({ref, socket, transport}) do
    clientname = stringify_clientname(socket)

    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}])

    :gen_server.enter_loop(__MODULE__, [], %{
      socket: socket,
      transport: transport,
      clientname: clientname
    })
  end

  def handle_info(
        {:tcp, _, message},
        %{socket: socket, transport: transport, clientname: clientname} = state
      ) do
    Logger.info(fn -> "Message from: #{clientname}: #{inspect(message)}." end)

    {:noreply, state}
  end

  def handle_info({:tcp_error, _, reason}, %{clientname: clientname} = state) do
    Logger.info(fn -> "Error #{clientname}: #{inspect(reason)}" end)

    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, _}, %{clientname: clientname} = state) do
    Logger.info(fn -> "Client #{clientname} disconnected" end)

    {:stop, :normal, state}
  end

  defp stringify_clientname(socket) do
    {:ok, {addr, port}} = :inet.clientname(socket)

    address =
      addr
      |> :inet_parse.ntoa()
      |> to_string()

    "#{address}:#{port}"
  end
end
