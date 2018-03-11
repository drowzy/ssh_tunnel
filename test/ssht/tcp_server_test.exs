defmodule SSHt.TcpServerTest do
  use ExUnit.Case
  alias SSHt.TcpProxy

  # setup do
  #   {:ok, ls} = TcpProxy.listen(path, :tcpip)
  #   {:ok, %{ls: ls, port: port}}
  # end
  setup do
    {:ok, pid} = SSHt.start_link

    on_exit fn ->
      assert_down(pid)
    end

    :ok
  end

  describe "with :unix" do
    setup do
      Temp.track!()
      dir = Temp.mkdir!("test")
      path = Path.join(dir, "/test.sock")

      {:ok, ls} = TcpProxy.listen(path, :unix)
      {:ok, %{ls: ls, path: path}}
    end

    test "creates a local socket at the provided path", %{path: path} do
      assert File.exists?(path)
    end

    test "can close listening socket", %{ls: ls} do
      assert :ok = TcpProxy.close(ls)
    end

    test "runs the callback with data from the socket", %{path: path, ls: ls, path: path} do
      pid = self()
      callback = &send(pid, {:msg, &1})

      Task.start(fn ->
        TcpProxy.accept(ls, callback)
      end)

      {:ok, sock} = :gen_tcp.connect({:local, path}, 0, [:binary, active: false, packet: 4])
      :gen_tcp.send(sock, "foo\n")

      assert_receive {:msg, _data}, 5000
    end
  end

  describe "with :tcpip" do
    setup do
      port = 24040
      {:ok, ls} = TcpProxy.listen(port, :tcpip)
      {:ok, %{ls: ls, port: port}}
    end

    test "runs the callback when receiving data", %{port: port, ls: ls} do
      pid = self()
      callback = &send(pid, {:msg, &1})

      Task.start(fn ->
        TcpProxy.accept(ls, callback)
      end)

      {:ok, sock} = :gen_tcp.connect('localhost', port, [:binary, active: false, packet: 4])
      :gen_tcp.send(sock, "foo\n")

      assert_receive {:msg, _data}, 5000
    end
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
