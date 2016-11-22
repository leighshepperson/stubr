defmodule StubrTest do
  use ExUnit.Case, async: true
  alias Stubr, as: SUT
  doctest SUT

  describe "SUT.stub!/2" do
    test "creates a stub" do
      stubbed = SUT.stub!([ceil: fn 1.9 -> :ok end])
      assert stubbed.ceil(1.9) == :ok
    end

    test "creates a stub with options" do
      stubbed = SUT.stub!([ceil: fn 1.9 -> :ok end], call_info: true, module: Float, auto_stub: true)
      assert stubbed.ceil(1.9) == :ok
      assert stubbed.floor(1.4) == 1.0
      assert stubbed.__stubr__(call_info: :ceil) == [%{input: [1.9], output: :ok}]
    end
  end

  describe "Stubr.spy!/2" do
    test "creates a stub of a module with call info and auto stub options set to true" do
      spy = SUT.spy!(Float)
      assert spy.ceil(1.9) == 2.0
      assert spy.__stubr__(call_info: :ceil) == [%{input: [1.9], output: 2.0}]
    end
  end

  describe "Stubr.call_info/2" do
    test "returns the call info for the stubbed module" do
      stubbed = SUT.stub!([
        ceil: fn 0.8 -> :stubbed_return end
      ], module: Float, auto_stub: true, call_info: true)

      stubbed.ceil(0.8)

      assert SUT.call_info(stubbed, :ceil) == [
        %{input: [0.8], output: :stubbed_return}
      ]
    end

    test "returns empty list if no call info for a stubbed function" do
      stubbed = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      assert SUT.call_info(stubbed, :ceil) == []
    end
  end

  describe "Stubr.called_with?/3" do
    test "returns true if stubbed function is called with single argument" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      assert SUT.called_with?(stub, :foo, [:bar])
    end

    test "returns true if stubbed function is called with multiple arguments" do
      stub = SUT.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      assert SUT.called_with?(stub, :foo, [:bar, :baz, :qux])
    end

    test "returns false if stubbed function is not called with arguments" do
      stub = SUT.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      refute SUT.called_with?(stub, :foo, [:alpha, :beta])
    end
  end

  describe "Stubr.called_where?/3" do
    test "returns true if the invocation of the anonymous function returns true when applied to a single argument" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error})
      assert SUT.called_where?(stub, :foo, fn [a] -> Map.has_key?(a, :bar) end)
    end

    test "returns true if the invocation of the anonymous function returns true when applied to multiple arguments" do
      stub = SUT.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error}, :bar, :qux)
      assert SUT.called_where?(stub, :foo, fn [a, _, c] -> Map.has_key?(a, :bar) && c == :qux end)
    end

    test "returns true if truthy on at least one of the function calls" do
      stub = SUT.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar, :qux)
      stub.foo(%{baz: :ok})

      fun = fn
        [%{baz: _}] -> true
        [:bar] -> nil
        [:bar, :qux] -> false
      end

      assert SUT.called_where?(stub, :foo, fun)
    end

    test "returns false if falsey on all the arguments to the function call" do
      stub = SUT.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar, :qux)
      stub.foo(%{baz: :ok})

      fun = fn _ -> false end

      refute SUT.called_where?(stub, :foo, fun)
    end
  end

  describe "Stubr.called_once?/2" do

    test "returns true if the function was called once" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      assert SUT.called_once?(stub, :foo)
    end

    test "returns false if the function was not called once" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      refute SUT.called_once?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      refute SUT.called_once?(stub, :foo)
    end

  end

  describe "Stubr.called_twice?/2" do

    test "returns true if the function was called twice" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      assert SUT.called_twice?(stub, :foo)
    end

    test "returns false if the function was not called twice" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute SUT.called_twice?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      refute SUT.called_twice?(stub, :foo)
    end

  end

  describe "Stubr.called_thrice?/2" do

    test "returns true if the function was called twice" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:bar)

      assert SUT.called_thrice?(stub, :foo)
    end

    test "returns false if the function was not called twice" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute SUT.called_thrice?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      refute SUT.called_thrice?(stub, :foo)
    end

  end

  describe "Stubr.called_many?/2" do
    test "returns true if the function was called n-many times" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:bar)

      assert SUT.called_many?(stub, :foo, 3)
    end

    test "returns false if the function was not called n - many times" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute SUT.called_many?(stub, :foo, 2)
    end

    test "returns false if the function was never called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)
      refute SUT.called_many?(stub, :foo, 1)
    end

  end

  describe "Stubr.first_call/2" do
    test "returns the first call" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz)
      assert SUT.first_call(stub, :foo) == [:bar, :baz]
    end

  end

  describe "Stubr.second_call/2" do

    test "returns the second call" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)

      assert SUT.second_call(stub, :foo) == [:bar, :qux]
    end

  end

  describe "Stubr.third_call/2" do
    test "returns the third call" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert SUT.third_call(stub, :foo) == [:bar, :quxx]
    end
  end

  describe "Stubr.get_call/3" do
    test "returns the nth call" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert SUT.get_call(stub, :foo, 1) == [:bar, :baz]
      assert SUT.get_call(stub, :foo, 2) == [:bar, :qux]
      assert SUT.get_call(stub, :foo, 3) == [:bar, :quxx]

    end

  end

  describe "Stubr.last_call/2" do
    test "returns the last call" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert SUT.last_call(stub, :foo) == [:bar, :quxx]

    end

  end

  describe "Stubr.call_count/2" do
    test "returns the number of times a stubbed function was called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz)

      assert SUT.call_count(stub, :foo) == 3
    end

  end

  describe "Stubr.call_count/3" do
    test "returns the number of times a stubbed function was called with a particular argument" do
      stub = SUT.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end ], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz, :qux)

      assert SUT.call_count(stub, :foo, [:bar]) == 2
      assert SUT.call_count(stub, :foo, [:baz, :qux]) == 1
    end

  end

  describe "Stubr.called?/2" do
    test "returns true if the stubbed function was called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)

      assert SUT.called?(stub, :foo)
    end

    test "returns false if the stubbed function was not called" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)

      assert SUT.called?(stub, :foo)
    end

  end

  describe "Stubr.called_with_exactly?/3" do
    test "returns true if the stubbed function was called with the exact arguments" do
      stub = SUT.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:baz, :qux)

      assert SUT.called_with_exactly?(stub, :foo, [[:bar, :baz], [:baz, :qux]])
    end

    test "returns false if the stubbed function was not called with the exact arguments" do
      stub = SUT.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)

      assert SUT.called_with_exactly?(stub, :foo, [[:bar], [:bar]])
    end

  end

  describe "Stubr.returned?/3" do
    test "returns true if the stubbed function returns the value at any point" do
      stub = SUT.stub!([
        foo: fn "bar" -> {:ok} end,
        foo: fn _, _ -> :ok end
      ], call_info: true)

      stub.foo("bar")
      stub.foo(:baz, :qux)

      assert SUT.returned?(stub, :foo, :ok)
      assert SUT.returned?(stub, :foo, {:ok})
    end

    test "returns false if the stubbed function does not return the value at any point" do
      stub = SUT.stub!([
        foo: fn "bar" -> {:ok} end,
        foo: fn _, _ -> :ok end
      ], call_info: true)

      stub.foo("bar")
      stub.foo(:baz, :qux)

      refute SUT.returned?(stub, :foo, :error)
    end

  end
end
