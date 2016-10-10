defmodule StubrCallInfoTest do
  use ExUnit.Case, async: true
  alias Stubr, as: SUT

  test "gets the call info of a function" do
    stubbed = SUT.stub!([
      {:ceil, fn 0.8 -> :stubbed_return end},
      {:parse, fn _ -> :stubbed_return end},
      {:round, fn(_, 1) -> :stubbed_return end},
      {:round, fn(1, 2) -> :stubbed_return end}
    ], module: Float, auto_stub: true)

    stubbed.ceil(0.8)
    stubbed.parse("0.3")
    stubbed.round(8, 1)
    stubbed.round(1, 2)
    stubbed.round(1.2)
    stubbed.round(1.324, 2)
    stubbed.ceil(1.2)
    stubbed.ceil(1.2345, 2)
    stubbed.to_string(2.3)

    assert stubbed.__stubr__(call_info: :ceil) == [
      %{input: [0.8], output: :stubbed_return},
      %{input: [1.2], output: 2.0},
      %{input: [1.2345, 2], output: 1.24}
    ]

    assert stubbed.__stubr__(call_info: :parse) == [
      %{input: ["0.3"], output: :stubbed_return}
    ]

    assert stubbed.__stubr__(call_info: :round) == [
      %{input: [8, 1], output: :stubbed_return},
      %{input: [1, 2], output: :stubbed_return},
      %{input: [1.2], output: 1.0},
      %{input: [1.324, 2], output: 1.32}
    ]

    assert stubbed.__stubr__(call_info: :to_string) == [
      %{input: [2.3], output: "2.3"}
    ]
  end
end
