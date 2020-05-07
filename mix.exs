defmodule BreakingBad.Mixfile do
  use Mix.Project

  def project do
    [
      app: :breaking_bad,
      version: "0.1.0",
      elixir: "~> 1.3",
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def package do
    [
      contributors: ["TV4 Infrastruktur"],
      maintainers: ["TV4 Infrastruktur"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/TV4/breaking_bad"}
    ]
  end

  def application do
    [
      applications: [:logger],
      mod: {BreakingBad, []}
    ]
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.2", only: :dev, runtime: false}
    ]
  end
end
