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

  test "It can create a stub with a function that matches a pattern" do
    stubbed = Stubr.stub([{:good_bye, fn(1, 4) -> :canned_response end}])

    assert stubbed.module_info[:exports][:good_bye] == 2
    assert stubbed.good_bye(1, 4) == :canned_response
  end

  test "It can creates a stub with a function that matches multiple patterns" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end},
      {:good_bye, fn(1, :ok, 1) -> :other_canned_response end},
      {:good_bye, fn([1, _, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:good_bye, fn(x, y, z) -> x + y + z end}
    ])

    assert stubbed.module_info[:exports][:good_bye] == 3
    assert stubbed.good_bye(1, 4, 9) == :canned_response
    assert stubbed.good_bye(1, :ok, 1) == :other_canned_response
    assert stubbed.good_bye([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubbed.good_bye(1, 2, 3) == 6
  end

  test "It can create a stub with more than one function" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end},
      {:au_revoir, fn(1, :ok, 1) -> :other_canned_response end},
      {:hello, fn([1, 2, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:bonjour, fn(x, 3, z) -> [x, :ok, x*z] end},
      {:bonjour, fn(x, y, z) -> x + y + z end}
    ])

    assert stubbed.module_info[:exports][:good_bye] == 3
    assert stubbed.good_bye(1, 4, 9) == :canned_response
    assert stubbed.au_revoir(1, :ok, 1) == :other_canned_response
    assert stubbed.hello([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubbed.bonjour(2, 3, 3) == [2, :ok, 6]
    assert stubbed.bonjour(1, 2, 3) == 6
  end

  test "If no patterns match, then it throws a FunctionClauseError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end}
    ])

    assert_raise FunctionClauseError, fn ->
      stubbed.good_bye(1, 1, 1)
    end
  end

  test "If the stub contains no function, then it throws an UndefinedFunctionError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end}
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.bonjour(1, 4, 8)
    end
  end

  test "It can stub an overloaded function" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end},
      {:good_bye, fn(1, 4) -> :two_params end},
      {:good_bye, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert stubbed.good_bye(1, 4, 9) == :three_params
    assert stubbed.good_bye(1, 4) == :two_params
    assert stubbed.good_bye(1, 4, 9, 7) == :four_params
  end

  test "If there is no function to overload, then it throws an UndefinedFunctionError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end},
      {:good_bye, fn(1, 4) -> :two_params end},
      {:good_bye, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.good_bye(1, 1, 1, 1, 1)
    end
  end

  test "It can create a stub by passing in arguments as variables" do
    function_name = :good_bye
    function_impl = fn(x, y, z) -> x + y - z end

    stubbed = Stubr.stub([{function_name, function_impl}])

    assert stubbed.good_bye(1, 2, 3) == 0
  end

  test "It can create a stub if the function is defined in another module" do
    defmodule Test, do: def test(1, 2), do: :ok

    stubbed = Stubr.stub([{:test, &Test.test/2}])

    assert stubbed.test(1, 2) == :ok
  end

  test "It can stub a dependency" do
    stubbed = Stubr.stub([{:foo, fn(1, 2) -> :ok end}])

    assert HasDependency.bar(stubbed) == :ok
  end

  test "If the module to stub does not contain a function matching arity, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      Stubr.stub(HasMissingFunction, [
        {:foo, fn(1) -> :ok end},
        {:foo, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "If the module to stub does not contain a function, then it throws an UndefinedFunctionError error" do
    assert_raise UndefinedFunctionError, fn ->
      Stubr.stub(HasMissingFunction, [
        {:foo, fn(1, 2) -> :ok end},
        {:bar, fn(1, 3, 7) -> :ok end}
      ])
    end
  end

  test "If the module to stub contains all the functions, then it creates a stub" do
    stubbed = Stubr.stub(HasMissingFunction, [
      {:foo, fn(1, 2) -> :ok end},
      {:foo, fn(4, 2) -> :ok end}
    ])

    assert stubbed.foo(1, 2) == :ok
    assert stubbed.foo(4, 2) == :ok
  end
end
