defmodule SSHt do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    children = [
      {Task.Supervisor, name: SSHt.TaskSupervisor}
    ]

    supervise(children, strategy: :one_for_one)
  end

  defdelegate connect(opts), to: SSHt.Conn
end
