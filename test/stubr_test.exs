defmodule StubrTest do
  use ExUnit.Case
  import Stubr
  doctest Stubr

  test "Can create a new module with a function that accepts fixed parameters" do
    actual = stub(nil, [{:good_bye, [1, 4, 3], :canned_response}])

    assert actual.module_info[:module] == UniqueName
    assert actual.module_info[:exports][:good_bye] == 3
    assert actual.good_bye(1, 4, 3) == :canned_response
  end

end
