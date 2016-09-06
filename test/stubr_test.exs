defmodule StubrTest do
  use ExUnit.Case
  alias Stubr.Errors.ModuleExistsError
  import Stubr
  doctest Stubr

  # test "Can create a stub with a unique name" do
  #   defmodule Hello do end

  #   actual = stub(Hello, [{:good_bye, [0,4,8], fn i -> 1 end}])

  #   assert actual == UniqueName

  #   IO.inspect actual.good_bye
  # end

  test "Can stub a function that exists in a module" do
    defmodule Hello do def good_bye, do: :ok end

    actual = stub(Hello, [{:good_bye, [1, 2, 3], fn (a, b, c) -> :ok end}])
  end

  # test "Raises an error if the stub name matches an in-memory module's name" do
  #   defmodule Hello do end

  #   assert_raise ModuleExistsError, "A module matching the name of the stub already exists", fn ->
  #     stub(Hello)
  #   end
  # end
end
