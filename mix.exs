defmodule Stubr.Mixfile do
  use Mix.Project

  def project do
    [app: :stubr,
     version: "1.3.2",
     elixir: "~> 1.3",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.3.5", only: [:dev]},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    A stubbing framework for Elixir
    """
  end

  defp package do
    [
      name: :stubr,
      files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
      maintainers: ["Leigh Shepperson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/leighshepperson/stubr",
               "Docs" => "https://github.com/leighshepperson/stubr"}
    ]
  end

end
