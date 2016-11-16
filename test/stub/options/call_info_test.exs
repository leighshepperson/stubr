defmodule Stubr.Stub.Options.CallInfoTest do
  use ExUnit.Case, async: true
  alias Stubr.Stub, as: SUT

  describe "call_info option" do

    test "gets the call info of a function if the call_info option is true" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end,
        parse: fn _ -> :stubbed_return end,
        round: fn(_, 1) -> :stubbed_return end,
        round: fn(1, 2) -> :stubbed_return end
      ], module: Float, auto_stub: true, call_info: true)

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

    test "does not get the call info of a function if the call_info option is false" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end
      ], module: Float, auto_stub: true, call_info: false)

      assert_raise StubrError, "The call_info option must be set and equal to true", fn ->
        stubbed.__stubr__(call_info: :ceil)
      end
    end

    test "does not get the call info of a function if the call_info option is not set" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end
      ], module: Float, auto_stub: true)

      assert_raise StubrError, "The call_info option must be set and equal to true", fn ->
        stubbed.__stubr__(call_info: :ceil)
      end
    end

    test "returns the call info for the stubbed" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end
      ], module: Float, auto_stub: true, call_info: true)

      stubbed.ceil(0.8)

      assert SUT.call_info!(stubbed, :ceil) == [
        %{input: [0.8], output: :stubbed_return}
      ]
    end

    test "returns empty list if no call info for a stubbed function" do
      stubbed = SUT.create!([foo: fn _ -> :ok end], call_info: true)

      assert SUT.call_info!(stubbed, :ceil) == []
    end
  end
end
