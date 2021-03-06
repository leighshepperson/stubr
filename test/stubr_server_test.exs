defmodule StubrServerTest do
  use ExUnit.Case, async: true
  alias StubrServer, as: SUT

  setup do
    {:ok, stubr_server} = SUT.start_link
    {:ok, stubr_server: stubr_server}
  end

  test "invokes a stubbed function", %{stubr_server: stubr_server} do
    assert SUT.add(stubr_server, :function, {:get, fn i -> i*i end}) == :ok
    assert SUT.invoke(stubr_server, {:get, [2]}) == {:ok, 4}
  end

  test "invokes a stubbed function in pattern matched order", %{stubr_server: stubr_server} do
    assert SUT.add(stubr_server, :function, {:foo, fn 1 -> "a" end}) == :ok
    assert SUT.add(stubr_server, :function, {:foo, fn 2 -> "b" end}) == :ok
    assert SUT.add(stubr_server, :function, {:foo, fn i -> i*i end}) == :ok
    assert SUT.invoke(stubr_server, {:foo, [1]}) == {:ok, "a"}
    assert SUT.invoke(stubr_server, {:foo, [2]}) == {:ok, "b"}
    assert SUT.invoke(stubr_server, {:foo, [3]}) == {:ok, 9}
  end

  test "errors if function is not stubbed", %{stubr_server: stubr_server} do
    assert SUT.invoke(stubr_server, {:set, [2]}) == {:error, UndefinedFunctionError}
  end

  test "defers to module function if not stubbed", %{stubr_server: stubr_server} do
    assert SUT.set(stubr_server, :module, Float) == :ok
    assert SUT.invoke(stubr_server, {:ceil, [2.9]}) == {:ok, 3.0}
  end

  test "gets call info in order of calls", %{stubr_server: stubr_server} do
    assert SUT.add(stubr_server, :call_info, {:get, %{input: [0, 1, 2], output: 3}}) == :ok
    assert SUT.add(stubr_server, :call_info, {:get, %{input: [:foo, :bar], output: :baz}}) == :ok
    assert SUT.get(stubr_server, :call_info, :get) ==
      {:ok, [%{input: [0, 1, 2], output: 3}, %{input: [:foo, :bar], output: :baz}]}
  end

end
