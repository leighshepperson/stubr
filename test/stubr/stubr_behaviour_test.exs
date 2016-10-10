defmodule StubrBehaviourTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  alias Stubr, as: SUT

  defmodule FooBehaviour do
    @callback foo(bar :: String.t) :: integer()
  end

  test "returns a warning if the stub does not implement a behaviour" do
    assert capture_io(:stderr, fn ->
      SUT.stub!([{:bar, fn _ -> 4 end}], behaviour: FooBehaviour) end
    ) =~ "warning: undefined behaviour function foo/1"

    assert capture_io(:stderr, fn ->
      SUT.stub!([{:foo, fn(_, _) -> 4 end}], behaviour: FooBehaviour) end
    ) =~ "warning: undefined behaviour function foo/1"
  end

  test "succeeds if the stub implements a behaviour" do
    assert capture_io(:stderr, fn ->
      SUT.stub!([{:foo, fn _ -> 4 end}], behaviour: FooBehaviour) end
    ) == ""
  end

end