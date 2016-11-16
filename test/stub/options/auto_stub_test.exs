defmodule Stubr.Stub.Options.AutoStubTest do
  use ExUnit.Case, async: true
  alias Stubr.Stub, as: SUT

  describe "auto_stub option" do

    test "defers to the original functionality of the input module if auto stub is true" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end,
        parse: fn _ -> :stubbed_return end,
        round: fn(_, 1) -> :stubbed_return end,
        round: fn(1, 2) -> :stubbed_return end
      ], module: Float, auto_stub: true)

      assert stubbed.ceil(0.8) == :stubbed_return
      assert stubbed.parse("0.3") == :stubbed_return
      assert stubbed.round(8, 1) == :stubbed_return
      assert stubbed.round(1, 2) == :stubbed_return
      assert stubbed.round(1.2) == 1
      assert stubbed.round(1.324, 2) == 1.32
      assert stubbed.ceil(1.2) == 2
      assert stubbed.ceil(1.2345, 2) == 1.24
      assert stubbed.to_string(2.3) == "2.3"
    end

    test "does not defer to the original functionality of the input module if auto stub is false" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end,
        parse: fn _ -> :stubbed_return end,
        round: fn(_, 1) -> :stubbed_return end,
        round: fn(1, 2) -> :stubbed_return end
      ], module: Float, auto_stub: false)

      assert stubbed.ceil(0.8) == :stubbed_return
      assert stubbed.parse("0.3") == :stubbed_return
      assert stubbed.round(8, 1) == :stubbed_return
      assert stubbed.round(1, 2) == :stubbed_return

      assert_raise UndefinedFunctionError, fn ->
        assert stubbed.round(1.2) == 1
      end
    end

    test "does not defer to the original functionality of the input module if auto stub is not set" do
      stubbed = SUT.create!([
        ceil: fn 0.8 -> :stubbed_return end,
        parse: fn _ -> :stubbed_return end,
        round: fn(_, 1) -> :stubbed_return end,
        round: fn(1, 2) -> :stubbed_return end
      ], module: Float)

      assert stubbed.ceil(0.8) == :stubbed_return
      assert stubbed.parse("0.3") == :stubbed_return
      assert stubbed.round(8, 1) == :stubbed_return
      assert stubbed.round(1, 2) == :stubbed_return

      assert_raise UndefinedFunctionError, fn ->
        assert stubbed.round(1.2) == 1
      end
    end
  end
end
