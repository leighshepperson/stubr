defmodule Stubr.Name.GeneratorStatic do
  def generate() do
    (for i <- 1..32, do: :random.uniform(26) + 96)
    |> to_string
    |> String.capitalize
  end
end