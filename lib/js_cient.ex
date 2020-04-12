defmodule JsClient do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- mdoc -->")
             |> Enum.drop(1)
             |> hd()
end
