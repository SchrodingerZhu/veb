defmodule Veb.Mixfile do
  use Mix.Project

  def project do
    [app: :veb,
     version: "0.2.3",
     elixir: "~> 1.7",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     name: "veb",
     licenses: ["MIT"],
     maintainers: ["SchrodingerZhu(朱一帆)"],
     links: %{"SchrodingerZhu's GitHub" => "https://github.com/SchrodingerZhu"},
     source_url: "https://github.com/SchrodingerZhu/veb",
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ex_doc, "~> 0.19-rc", only: :dev, runtime: false}]
  end
  defp package do
    [
      name: :veb,
      licenses: ["MIT"],
      maintainers: ["SchrodingerZhu(朱一帆)"],
      links: %{"SchrodingerZhu's GitHub" => "https://github.com/SchrodingerZhu"},
      source_url: "https://github.com/SchrodingerZhu/veb",
      description: description(),
      deps: deps()]
  end
  defp description do
    """
    This is the functional implement of van Emde Boas Tree, which can maintain the information of Integers efficiently.
    """
  end
end
