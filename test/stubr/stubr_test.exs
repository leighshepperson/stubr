defmodule StubrTest do
  use ExUnit.Case, async: true
  doctest Stubr

  defmodule HasMissingFunction,
    do: def foo(1, 2), do: :ok

  defmodule Dependency,
    do: def foo(1, 2), do: :expensive_call

  defmodule HasDependency do
    def bar(dependency \\ Dependency) do
      dependency.foo(1, 2)
    end
  end

  test "create a stub with a function that matches a pattern" do
    stubbed = Stubr.stub!([{:foo, fn(1, 4) -> :canned_response end}])

    assert stubbed.module_info[:exports][:foo] == 2
    assert stubbed.foo(1, 4) == :canned_response
  end

  test "create a stub with a function that matches multiple patterns" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :canned_response end},
      {:foo, fn(1, :ok, 1) -> :other_canned_response end},
      {:foo, fn([1, _, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:foo, fn(x, y, z) -> x + y + z end}
    ])

    assert stubbed.module_info[:exports][:foo] == 3
    assert stubbed.foo(1, 4, 9) == :canned_response
    assert stubbed.foo(1, :ok, 1) == :other_canned_response
    assert stubbed.foo([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubbed.foo(1, 2, 3) == 6
  end

  test "create a stub with more than one function" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :canned_response end},
      {:bar, fn(1, :ok, 1) -> :other_canned_response end},
      {:baz, fn([1, 2, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:qux, fn(x, 3, z) -> [x, :ok, x*z] end},
      {:qux, fn(x, y, z) -> x + y + z end}
    ])

    assert stubbed.module_info[:exports][:foo] == 3
    assert stubbed.foo(1, 4, 9) == :canned_response
    assert stubbed.bar(1, :ok, 1) == :other_canned_response
    assert stubbed.baz([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubbed.qux(2, 3, 3) == [2, :ok, 6]
    assert stubbed.qux(1, 2, 3) == 6
  end

  test "If no patterns match, then it throws a FunctionClauseError" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :canned_response end}
    ])

    assert_raise FunctionClauseError, fn ->
      stubbed.foo(1, 1, 1)
    end
  end

  test "If a function is not provided, then it throws an UndefinedFunctionError if called" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :three_params end}
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.qux(1, 4, 8)
    end
  end

  test "stub an overloaded function" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :three_params end},
      {:foo, fn(1, 4) -> :two_params end},
      {:foo, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert stubbed.foo(1, 4, 9) == :three_params
    assert stubbed.foo(1, 4) == :two_params
    assert stubbed.foo(1, 4, 9, 7) == :four_params
  end

  test "If there is no function to overload, then it throws an UndefinedFunctionError" do
    stubbed = Stubr.stub!([
      {:foo, fn(1, 4, 9) -> :three_params end},
      {:foo, fn(1, 4) -> :two_params end},
      {:foo, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.foo(1, 1, 1, 1, 1)
    end
  end

  test "create a stub by passing in arguments as variables" do
    function_name = :foo
    function_impl = fn(x, y, z) -> x + y - z end

    stubbed = Stubr.stub!([{function_name, function_impl}])

    assert stubbed.foo(1, 2, 3) == 0
  end

  test "create a stub if the function is defined in another module" do
    defmodule Test, do: def test(1, 2), do: :ok

    stubbed = Stubr.stub!([{:test, &Test.test/2}])

    assert stubbed.test(1, 2) == :ok
  end

  test "stub a dependency" do
    stubbed = Stubr.stub!([{:foo, fn(1, 2) -> :ok end}])

    assert HasDependency.bar(stubbed) == :ok
  end

  test "If the module to stub does not contain a function matching arity, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      Stubr.stub!(HasMissingFunction, [
        {:foo, fn(1) -> :ok end},
        {:foo, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "If the module to stub does not contain a function, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      Stubr.stub!(HasMissingFunction, [
        {:foo, fn(1, 2) -> :ok end},
        {:bar, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "If the module to stub contains all the functions, then it creates a stub" do
    stubbed = Stubr.stub!(HasMissingFunction, [
      {:foo, fn(1, 2) -> :ok end},
      {:foo, fn(4, 2) -> :ok end}
    ])

    assert stubbed.foo(1, 2) == :ok
    assert stubbed.foo(4, 2) == :ok
  end

  test "defers to the original functionality of the stubbed module if auto stub is true" do
    stubbed = Stubr.stub!(Float, [
      {:ceil, fn 0.8 -> :stubbed_return end},
      {:parse, fn _ -> :stubbed_return end},
      {:round, fn(_, 1) -> :stubbed_return end},
      {:round, fn(1, 2) -> :stubbed_return end}
    ], auto_stub: true)

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

  test "does not defer to the original functionality of the stubbed module if auto stub is false" do
    stubbed = Stubr.stub!(Float, [
      {:ceil, fn 0.8 -> :stubbed_return end},
      {:parse, fn _ -> :stubbed_return end},
      {:round, fn(_, 1) -> :stubbed_return end},
      {:round, fn(1, 2) -> :stubbed_return end}
    ], auto_stub: false)

    assert stubbed.ceil(0.8) == :stubbed_return
    assert stubbed.parse("0.3") == :stubbed_return
    assert stubbed.round(8, 1) == :stubbed_return
    assert stubbed.round(1, 2) == :stubbed_return

    assert_raise UndefinedFunctionError, fn ->
      assert stubbed.round(1.2) == 1
    end
  end

  test "does not defer to the original functionality of the stubbed module if auto stub is not set" do
    stubbed = Stubr.stub!(Float, [
      {:ceil, fn 0.8 -> :stubbed_return end},
      {:parse, fn _ -> :stubbed_return end},
      {:round, fn(_, 1) -> :stubbed_return end},
      {:round, fn(1, 2) -> :stubbed_return end}
    ])

    assert stubbed.ceil(0.8) == :stubbed_return
    assert stubbed.parse("0.3") == :stubbed_return
    assert stubbed.round(8, 1) == :stubbed_return
    assert stubbed.round(1, 2) == :stubbed_return

    assert_raise UndefinedFunctionError, fn ->
      assert stubbed.round(1.2) == 1
    end
  end
end
