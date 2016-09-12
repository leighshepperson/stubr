defmodule StubrTest do
  use ExUnit.Case
  doctest Stubr
  import Stubr

  test "Can create a new module with a function accepting a single set of fixed parameters" do
    stubed = stub({:good_bye, fn(1, 4) -> :canned_response end})

    assert stubed.module_info[:exports][:good_bye] == 2
    assert stubed.good_bye(1, 4) == :canned_response
  end

end
