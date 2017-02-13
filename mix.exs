defmodule Apns.Mixfile do
  use Mix.Project

  def project do
    [app: :apns,
     version: "0.1.0",
     lockfile: "mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :poolboy, :gun],
     mod: {APNS, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:connection, "~> 1.0"},
      {:poison, "~> 1.5 or ~> 2.0"},
      {:poolboy, "~> 1.5"},
      {:gun, git: "https://github.com/ninenines/gun.git"},
      {:joken, "~> 1.4"}
    ]
  end
end
