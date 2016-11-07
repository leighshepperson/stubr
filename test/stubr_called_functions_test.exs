defmodule StubrCalledFunctionsTest do
  use ExUnit.Case, async: true

  describe "Stubr.called_with?/3" do

    test "returns true if stubbed function is called with single argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      assert Stubr.called_with?(stub, :foo, [:bar])
    end

    test "returns true if stubbed function is called with multiple arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      assert Stubr.called_with?(stub, :foo, [:bar, :baz, :qux])
    end

    test "returns false if stubbed function is not called with arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(:bar, :baz, :qux)
      refute Stubr.called_with?(stub, :foo, [:alpha, :beta])
    end

  end

  describe "Stubr.called_where?/3" do

    test "returns true if the invocation of the anonymous function returns true when applied to a single argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error})
      assert Stubr.called_where?(stub, :foo, fn [a] -> Map.has_key?(a, :bar) end)
    end

    test "returns true if the invocation of the anonymous function returns true when applied to multiple arguments" do
      stub = Stubr.stub!([foo: fn _, _, _ -> :ok end], call_info: true)
      stub.foo(%{bar: :ok, qux: :error}, :bar, :qux)
      assert Stubr.called_where?(stub, :foo, fn [a, _, c] -> Map.has_key?(a, :bar) && c == :qux end)
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

      assert Stubr.called_where?(stub, :foo, fun)
    end

    test "returns false if falsey on all the arguments to the function call" do
      stub = Stubr.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar, :qux)
      stub.foo(%{baz: :ok})

      fun = fn _ -> false end

      refute Stubr.called_where?(stub, :foo, fun)
    end
  end

  describe "Stubr.call_count/2" do

    test "returns the number of times a stubbed function was called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz)
      assert Stubr.call_count(stub, :foo) == 3
    end

  end

  describe "Stubr.call_count/3" do

    test "returns the number of times a stubbed function was called with a particular argument" do
      stub = Stubr.stub!([foo: fn _ -> :ok end, foo: fn _, _ -> :ok end ], call_info: true)
      stub.foo(:bar)
      stub.foo(:bar)
      stub.foo(:baz, :qux)
      assert Stubr.call_count(stub, :foo, [:bar]) == 2
      assert Stubr.call_count(stub, :foo, [:baz, :qux]) == 1
    end

  end

  describe "Stubr.called/2" do

    test "returns true if the stubbed function was called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)

      assert Stubr.called?(stub, :foo)
    end

    test "returns false if the stubbed function was not called" do
      stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
      stub.foo(:bar)

      assert Stubr.called?(stub, :foo)
    end

  end
end
