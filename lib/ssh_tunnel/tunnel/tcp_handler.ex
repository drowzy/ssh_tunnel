defmodule SSHTunnel.Tunnel.TCPHandler do
  use GenServer
  require Logger

  def start_link(ref, socket, transport, opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [{ref, socket, transport, opts}])
    {:ok, pid}
  end

  def init({ref, socket, transport, opts}) do
    clientname = stringify_clientname(socket)
    target = Keyword.get(opts, :target)
    ssh_ref = Keyword.get(opts, :ssh_ref)

    {:ok, channel} = ssh_forward(ssh_ref, target)
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}])

    :gen_server.enter_loop(__MODULE__, [], %{
      socket: socket,
      transport: transport,
      ssh_ref: ssh_ref,
      channel: channel,
      clientname: clientname
    })
  end

  def handle_info(
        {:tcp, _, data},
        %{ssh_ref: ssh, channel: channel} = state
      ) do
    :ok = :ssh_connection.send(ssh, channel, data)

    {:noreply, state}
  end

  def handle_info({:tcp_error, _, reason}, %{clientname: clientname} = state) do
    Logger.info(fn -> "Error #{clientname}: #{inspect(reason)}" end)
    {:stop, :normal, state}
  end

  def handle_info(
        {:tcp_closed, _},
        %{clientname: clientname, channel: channel} = state
      ) do
    Logger.info(fn -> "Client #{clientname} disconnected channel #{channel}" end)

    {:stop, :normal, state}
  end

  def handle_info(
        {:ssh_cm, _, {:data, _, _, data}},
        %{socket: socket, transport: transport} = state
      ) do
    :ok = transport.send(socket, data)
    {:noreply, state}
  end

  def handle_info({:ssh_cm, _, {:eof, _channel_id}}, state) do
    {:stop, :normal, state}
  end

  def terminate(reason, %{ssh_ref: ssh, channel: channel}) do
    :ok = :ssh_connection.close(ssh, channel)
    Logger.info("terminated reason #{inspect(reason)}")
  end

  defp ssh_forward(ref, {_, {_, {_, path}}}) when is_binary(path),
    do: SSHTunnel.stream_local_forward(ref, path)

  defp ssh_forward(ref, {_, {local_port, {_, port} = to}}) when is_number(port),
    do: SSHTunnel.direct_tcpip(ref, {"127.0.0.1", local_port}, to)

  defp stringify_clientname(socket) do
    {:ok, {addr, port}} = :inet.peername(socket)

    address =
      case addr do
        :local ->
          "UNIX-SOCKET://"

        addr ->
          addr
          |> :inet_parse.ntoa()
          |> to_string()
      end

    "#{address}:#{port}"
  end
end
