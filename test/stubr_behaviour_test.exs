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
    ) =~ "undefined behaviour function foo/1"
  end

  test "returns a warning if the stub does not implement the correct overload" do
    assert capture_io(:stderr, fn ->
      SUT.stub!([{:foo, fn(_, _) -> 4 end}], behaviour: FooBehaviour) end
    ) =~ "undefined behaviour function foo/1"
  end

  test "returns a warning if the behaviour is undefined" do
    defmodule NoBehaviour, do: def foo, do: :ok

    assert capture_io(:stderr, fn ->
      SUT.stub!([{:foo, fn _ -> 4 end}], behaviour: NoBehaviour) end
    ) =~ "behaviour StubrBehaviourTest.NoBehaviour undefined"
  end

  test "succeeds if the stub implements a behaviour" do
    assert capture_io(:stderr, fn ->
      SUT.stub!([{:foo, fn _ -> 4 end}], behaviour: FooBehaviour) end
    ) == ""
  end

end
