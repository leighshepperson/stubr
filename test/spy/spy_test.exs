defmodule Stubr.SpyTest do
  use ExUnit.Case, async: true
  alias Stubr.Spy
  doctest Spy

  describe "Spy.spy!/2" do

    test "creates a stub of a module with call info and auto stub options set to true" do
      spy = Spy.spy!(Float)

      assert spy.ceil(1.9) == 2.0
      assert spy.__stubr__(call_info: :ceil) == [%{input: [1.9], output: 2.0}]
    end

  end

  describe "Spy.called_with?/3" do

    test "returns true if stubbed function is called with single argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      assert Spy.called_with?(stub, :foo, [:bar])
    end

    test "returns true if stubbed function is called with multiple arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      assert Spy.called_with?(stub, :foo, [:bar, :baz, :qux])
    end

    test "returns false if stubbed function is not called with arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      refute Spy.called_with?(stub, :foo, [:alpha, :beta])
    end

  end

  describe "Spy.called_where?/3" do

    test "returns true if the invocation of the anonymous function returns true when applied to a single argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error})
      assert Spy.called_where?(stub, :foo, fn [a] -> Map.has_key?(a, :bar) end)
    end

    test "returns true if the invocation of the anonymous function returns true when applied to multiple arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error}, :bar, :qux)
      assert Spy.called_where?(stub, :foo, fn [a, _, c] -> Map.has_key?(a, :bar) && c == :qux end)
    end

    test "returns true if truthy on at least one of the function calls" do
      stub = Stubr.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar, :qux)
      stub.foo(%{baz: :ok})

      fun = fn
        [%{baz: _}] -> true
        [:bar] -> nil
        [:bar, :qux] -> false
      end

      assert Spy.called_where?(stub, :foo, fun)
    end

    test "returns false if falsey on all the arguments to the function call" do
      stub = Stubr.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar, :qux)
      stub.foo(%{baz: :ok})

      fun = fn _ -> false end

      refute Spy.called_where?(stub, :foo, fun)
    end
  end

  describe "Spy.called_once?/2" do

    test "returns true if the function was called once" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      assert Spy.called_once?(stub, :foo)
    end

    test "returns false if the function was not called once" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      refute Spy.called_once?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      refute Spy.called_once?(stub, :foo)
    end

  end

  describe "Spy.called_twice?/2" do

    test "returns true if the function was called twice" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      assert Spy.called_twice?(stub, :foo)
    end

    test "returns false if the function was not called twice" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute Spy.called_twice?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      refute Spy.called_twice?(stub, :foo)
    end

  end

  describe "Spy.called_thrice?/2" do

    test "returns true if the function was called twice" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:bar)

      assert Spy.called_thrice?(stub, :foo)
    end

    test "returns false if the function was not called twice" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute Spy.called_thrice?(stub, :foo)
    end

    test "returns false if the function was never called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      refute Spy.called_thrice?(stub, :foo)
    end

  end

  describe "Spy.called_many?/2" do

    test "returns true if the function was called n-many times" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:bar)

      assert Spy.called_many?(stub, :foo, 3)
    end

    test "returns false if the function was not called n - many times" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      refute Spy.called_many?(stub, :foo, 2)
    end

    test "returns false if the function was never called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      refute Spy.called_many?(stub, :foo, 1)
    end

  end

  describe "Spy.first_call/2" do

    test "returns the first call" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz)
      assert Spy.first_call(stub, :foo) == [:bar, :baz]
    end

  end

  describe "Spy.second_call/2" do

    test "returns the second call" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)

      assert Spy.second_call(stub, :foo) == [:bar, :qux]
    end

  end

  describe "Spy.third_call/2" do

    test "returns the third call" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert Spy.third_call(stub, :foo) == [:bar, :quxx]
    end
  end

  describe "Spy.get_call/3" do

    test "returns the nth call" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert Spy.get_call(stub, :foo, 1) == [:bar, :baz]
      assert Spy.get_call(stub, :foo, 2) == [:bar, :qux]
      assert Spy.get_call(stub, :foo, 3) == [:bar, :quxx]

    end

  end

  describe "Spy.last_call/2" do

    test "returns the last call" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:bar, :qux)
      stub.foo(:bar, :quxx)

      assert Spy.last_call(stub, :foo) == [:bar, :quxx]

    end

  end

  describe "Spy.call_count/2" do

    test "returns the number of times a stubbed function was called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz)

      assert Spy.call_count(stub, :foo) == 3
    end

  end

  describe "Spy.call_count/3" do

    test "returns the number of times a stubbed function was called with a particular argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end ], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz, :qux)

      assert Spy.call_count(stub, :foo, [:bar]) == 2
      assert Spy.call_count(stub, :foo, [:baz, :qux]) == 1
    end

  end

  describe "Spy.called?/2" do

    test "returns true if the stubbed function was called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)

      assert Spy.called?(stub, :foo)
    end

    test "returns false if the stubbed function was not called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)

      assert Spy.called?(stub, :foo)
    end

  end

  describe "Spy.called_with_exactly?/3" do

    test "returns true if the stubbed function was called with the exact arguments" do
      stub = Stubr.stub!([foo: fn _, _ -> :ok end], call_info: true)

      stub.foo(:bar, :baz)
      stub.foo(:baz, :qux)

      assert Spy.called_with_exactly?(stub, :foo, [[:bar, :baz], [:baz, :qux]])
    end

    test "returns false if the stubbed function was not called with the exact arguments" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)

      stub.foo(:bar)
      stub.foo(:bar)

      assert Spy.called_with_exactly?(stub, :foo, [[:bar], [:bar]])
    end

  end

  describe "Spy.returned?/3" do

    test "returns true if the stubbed function returns the value at any point" do
      stub = Stubr.stub!([
        foo: fn "bar" -> {:ok} end,
        foo: fn _, _ -> :ok end
      ], call_info: true)

      stub.foo("bar")
      stub.foo(:baz, :qux)

      assert Spy.returned?(stub, :foo, :ok)
      assert Spy.returned?(stub, :foo, {:ok})
    end

    test "returns false if the stubbed function does not return the value at any point" do
      stub = Stubr.stub!([
        foo: fn "bar" -> {:ok} end,
        foo: fn _, _ -> :ok end
      ], call_info: true)

      stub.foo("bar")
      stub.foo(:baz, :qux)

      refute Spy.returned?(stub, :foo, :error)
    end

  end
end