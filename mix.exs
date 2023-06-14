defmodule RedisGraph.MixProject do
  use Mix.Project

  @description "A RedisGraph client library in Elixir with support for Cypher query building."
  @repo_url "https://github.com/AlexSandro19/redisgraph-ex-lib"
  @website_url "https://hexdocs.pm/ex_redisgraph/RedisGraph.html"
  @version "0.1.0"

  def project do
    [
      app: :ex_redisgraph,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      # Docs
      description: @description,
      package: package(),
      source_url: @repo_url,
      homepage_url: @website_url,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Alexandru Sandrovschii"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp docs do
    [
      main: "RedisGraph",
      source_ref: "v#{@version}",
      source_url: @repo_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redix, "~> 1.2"},
      {:castore, ">= 0.0.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.16.1", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
