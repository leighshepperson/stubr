defmodule StubrTest do
  use ExUnit.Case
  doctest Stubr
  import Stubr

  test "Creates a module with a function that executes if the arguments match a single pattern" do
    stubbed = stub([{:good_bye, fn(1, 4) -> :canned_response end}])

    assert stubbed.module_info[:exports][:good_bye] == 2
    assert stubbed.good_bye(1, 4) == :canned_response
  end

  test "Creates a module with a function defined by anonymous functions" do
    stubbed = stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end},
      {:good_bye, fn(1, :ok, 1) -> :other_canned_response end},
      {:good_bye, fn([1, 2, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:good_bye, fn(x, y, z) -> x + y + z end}
    ])

    assert stubbed.module_info[:exports][:good_bye] == 3
    assert stubbed.good_bye(1, 4, 9) == :canned_response
    assert stubbed.good_bye(1, :ok, 1) == :other_canned_response
    assert stubbed.good_bye([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubbed.good_bye(1, 2, 3) == 6
  end

  test "Creates a module with functions defined by anonymous functions" do
    stubbed = stub([
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

end
