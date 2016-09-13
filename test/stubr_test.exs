defmodule StubrTest do
  use ExUnit.Case
  doctest Stubr
  import Stubr

  test "Creates a module with a function that executes if the arguments match a single pattern" do
    stubed = stub([{:good_bye, fn(1, 4) -> :canned_response end}])

    assert stubed.module_info[:exports][:good_bye] == 2
    assert stubed.good_bye(1, 4) == :canned_response
  end

  test "Creates a module with a function defined by anonymous functions" do
    stubed = stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end},
      {:good_bye, fn(1, :ok, 1) -> :canned_response_1 end},
      {:good_bye, fn([1, 2, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:good_bye, fn(x, y, z) -> x + y + z end}
    ])

    assert stubed.module_info[:exports][:good_bye] == 3
    assert stubed.good_bye(1, 4, 9) == :canned_response
    assert stubed.good_bye(1, :ok, 1) == :canned_response_1
    assert stubed.good_bye([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubed.good_bye(1, 2, 3) == 6
  end

  test "Creates a module with functions defined by anonymous functions" do
    stubed = stub([
      {:good_bye, fn(1, 4, 9) -> :canned_response end},
      {:aurevoir, fn(1, :ok, 1) -> :canned_response_1 end},
      {:hello, fn([1, 2, :ok], %{2 => [a: "b"]}, true) -> {:ok} end},
      {:bonjour, fn(x, 3, z) -> [x, :ok, x*z] end},
      {:bonjour, fn(x, y, z) -> x + y + z end}
    ])

    assert stubed.module_info[:exports][:good_bye] == 3
    assert stubed.good_bye(1, 4, 9) == :canned_response
    assert stubed.aurevoir(1, :ok, 1) == :canned_response_1
    assert stubed.hello([1, 2,:ok], %{2 => [a: "b"]}, true) == {:ok}
    assert stubed.bonjour(2, 3, 3) == [2, :ok, 6]
    assert stubed.bonjour(1, 2, 3) == 6
  end

end
