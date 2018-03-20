defmodule SSHTunnel.MixProject do
  use Mix.Project

  @source "https://github.com/drowzy/ssh_tunnel"
  def project do
    [
      app: :ssh_tunnel,
      version: "0.1.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "SSHTunnel",
      description: "Create SSH tunnels using Erlang's SSH application",
      source_url: @source,
      homepage_url: @source,
      docs: [main: "SSHTunnel"],
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssh],
      mod: {SSHTunnel.Application, []}
    ]
  end

  defp package() do
    [
      maintainers: ["Simon Thörnqvist"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:temp, "~> 0.4", only: :test},
      {:ranch, "~> 1.4"},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end
end
