defmodule SSHTunnel.Application do
  @moduledoc """
  Application module
  """
  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: SSHTunnel.TunnelSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
