defmodule StubrTest do
  use ExUnit.Case, async: true
  alias Stubr, as: SUT
  doctest SUT

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
    stubbed = SUT.stub!([{:foo, fn(1, 4) -> :canned_response end}])

    assert stubbed.module_info[:exports][:foo] == 2
    assert stubbed.foo(1, 4) == :canned_response
  end

  test "create a stub with a function that matches multiple patterns" do
    stubbed = SUT.stub!([
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
    stubbed = SUT.stub!([
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

  test "if no patterns match, then it throws a FunctionClauseError" do
    stubbed = SUT.stub!([
      {:foo, fn(1, 4, 9) -> :canned_response end}
    ])

    assert_raise FunctionClauseError, fn ->
      stubbed.foo(1, 1, 1)
    end
  end

  test "if a function is not provided, then it throws an UndefinedFunctionError if called" do
    stubbed = SUT.stub!([
      {:foo, fn(1, 4, 9) -> :three_params end}
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.qux(1, 4, 8)
    end
  end

  test "stub an overloaded function" do
    stubbed = SUT.stub!([
      {:foo, fn(1, 4, 9) -> :three_params end},
      {:foo, fn(1, 4) -> :two_params end},
      {:foo, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert stubbed.foo(1, 4, 9) == :three_params
    assert stubbed.foo(1, 4) == :two_params
    assert stubbed.foo(1, 4, 9, 7) == :four_params
  end

  test "if there is no function to overload, then it throws an UndefinedFunctionError" do
    stubbed = SUT.stub!([
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

    stubbed = SUT.stub!([{function_name, function_impl}])

    assert stubbed.foo(1, 2, 3) == 0
  end

  test "create a stub if the function is defined in another module" do
    defmodule Test, do: def test(1, 2), do: :ok

    stubbed = SUT.stub!([{:test, &Test.test/2}])

    assert stubbed.test(1, 2) == :ok
  end

  test "stub a dependency" do
    stubbed = SUT.stub!([{:foo, fn(1, 2) -> :ok end}])

    assert HasDependency.bar(stubbed) == :ok
  end

  test "if the module to stub does not contain a function matching arity, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      SUT.stub!(HasMissingFunction, [
        {:foo, fn(1) -> :ok end},
        {:foo, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "if the module to stub does not contain a function, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      SUT.stub!(HasMissingFunction, [
        {:foo, fn(1, 2) -> :ok end},
        {:bar, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "if the module to stub contains all the functions, then it creates a stub" do
    stubbed = SUT.stub!(HasMissingFunction, [
      {:foo, fn(1, 2) -> :ok end},
      {:foo, fn(4, 2) -> :ok end}
    ])

    assert stubbed.foo(1, 2) == :ok
    assert stubbed.foo(4, 2) == :ok
  end

end
