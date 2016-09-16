defmodule StubrTest do
  use ExUnit.Case, async: true
  doctest Stubr

  test "Creates a stub with a function that matches a pattern" do
    stubbed = Stubr.stub([{:good_bye, fn(1, 4) -> :canned_response end}])

    assert stubbed.module_info[:exports][:good_bye] == 2
    assert stubbed.good_bye(1, 4) == :canned_response
  end

  test "Creates a stub with a single function that matches different patterns" do
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

  test "Creates a stub with more than one function" do
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

  test "If no patterns match, then throw a FunctionClauseError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end}
    ])

    assert_raise FunctionClauseError, fn ->
      stubbed.good_bye(1, 1, 1)
    end
  end

  test "If there is no function matching name, then throws an UndefinedFunctionError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end}
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.bonjour(1, 4, 8)
    end
  end

  test "Can stub a function of differing arity" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end},
      {:good_bye, fn(1, 4) -> :two_params end},
      {:good_bye, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert stubbed.good_bye(1, 4, 9) == :three_params
    assert stubbed.good_bye(1, 4) == :two_params
    assert stubbed.good_bye(1, 4, 9, 7) == :four_params
  end

  test "If there is no function matching arity, then throws an UndefinedFunctionError" do
    stubbed = Stubr.stub([
      {:good_bye, fn(1, 4, 9) -> :three_params end},
      {:good_bye, fn(1, 4) -> :two_params end},
      {:good_bye, fn(1, 4, 9, 7) -> :four_params end},
    ])

    assert_raise UndefinedFunctionError, fn ->
      stubbed.good_bye(1, 1, 1, 1, 1)
    end
  end

  test "Creates a stub by passing in variables" do
    function_name = :good_bye
    function_impl = fn(x, y, z) -> x + y - z end

    stubbed = Stubr.stub([{function_name, function_impl}])

    assert stubbed.good_bye(1, 2, 3) == 0
  end

  test "Creates a stub by passing in a function defined in another module" do
    defmodule Test do
      def test(1, 2), do: :ok
    end

    stubbed = Stubr.stub([{:test, &Test.test/2}])

    assert stubbed.test(1, 2) == :ok
  end
end
