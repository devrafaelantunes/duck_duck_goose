defmodule DuckDuckGoose.MixProject do
  use Mix.Project

  def project do
    [
      app: :duck_duck_goose,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [
        test: "test --no-start"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :libcluster],
      mod: {DuckDuckGoose.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libcluster, "~> 3.3.3"},
      {:cowboy, "~> 2.12"},
      {:jason, "~> 1.3"},
      {:local_cluster, "~> 1.2", only: [:test]},
      {:mimic, "~> 1.3", only: :test}
    ]
  end
end
