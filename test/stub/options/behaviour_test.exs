defmodule Stubr.Stub.Options.BehaviourTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO
  alias Stubr.Stub, as: SUT

  describe "behaviour option" do

    defmodule FooBehaviour do
      @callback foo(bar :: String.t) :: integer()
    end

    test "returns a warning if the stub does not implement a behaviour" do
      assert capture_io(:stderr, fn ->
        SUT.create!([{:bar, fn _ -> 4 end}], behaviour: FooBehaviour) end
      ) =~ "undefined behaviour function foo/1"
    end

    test "returns a warning if the stub does not implement the correct overload" do
      assert capture_io(:stderr, fn ->
        SUT.create!([{:foo, fn(_, _) -> 4 end}], behaviour: FooBehaviour) end
      ) =~ "undefined behaviour function foo/1"
    end

    test "returns a warning if the behaviour is undefined" do
      defmodule NoBehaviour, do: def foo, do: :ok

      assert capture_io(:stderr, fn ->
        SUT.create!([{:foo, fn _ -> 4 end}], behaviour: NoBehaviour) end
      ) =~ "behaviour Stubr.Stub.Options.BehaviourTest.NoBehaviour is undefined"
    end

    test "succeeds if the stub implements a behaviour" do
      assert capture_io(:stderr, fn ->
        SUT.create!([{:foo, fn _ -> 4 end}], behaviour: FooBehaviour) end
      ) == ""
    end

  end
end
