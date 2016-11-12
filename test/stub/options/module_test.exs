defmodule Stubr.Stub.ModuleTest do
  use ExUnit.Case, async: true
  alias Stubr.Stub, as: SUT

  describe "module option" do

    defmodule HasMissingFunction,
      do: def foo(1, 2), do: :ok

    test "if the module to stub does not contain a function matching arity,
      then it throws an UndefinedFunctionError error" do
      assert_raise UndefinedFunctionError, fn ->
        SUT.create_stub!([
          foo: fn(1) -> :ok end,
          foo: fn(1, 3, 7) -> :ok end
        ], module: HasMissingFunction)
      end
    end

    test "if the module to stub does not contain a function, then it throws
      an UndefinedFunctionError error" do
      assert_raise UndefinedFunctionError, fn ->
        SUT.create_stub!([
          foo: fn(1, 2) -> :ok end,
          bar: fn(1, 3, 7) -> :ok end
        ], module: HasMissingFunction)
      end
    end

    test "if the module to stub contains all the functions, then it creates a stub" do
      stubbed = SUT.create_stub!([
        foo: fn(1, 2) -> :ok end,
        foo: fn(4, 2) -> :ok end
      ], module: HasMissingFunction)

      assert stubbed.foo(1, 2) == :ok
      assert stubbed.foo(4, 2) == :ok
    end
  end

end