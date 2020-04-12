defmodule JsClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :js_client,
      version: "1.0.3",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{"Github page" => "https://github.com/lud/phoenix-js-router"},
      description: """
      A simple macro to crate a javascript client for Phoenix routes
      """
    }
  end

  defp docs do
    [
      main: "JsClient"
    ]
  end
end
