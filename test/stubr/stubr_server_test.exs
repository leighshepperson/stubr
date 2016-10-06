defmodule StubrServerTest do
  use ExUnit.Case, async: true
  alias StubrServer, as: SUT

  setup do
    {:ok, stubr_server} = StubrServer.start_link
    {:ok, stubr_server: stubr_server}
  end

  test "invokes a stubbed function", %{stubr_server: stubr_server} do
    assert StubrServer.add(stubr_server, :function, {:get, fn i -> i*i end}) == :ok
    assert StubrServer.invoke(stubr_server, {:get, [2]}) == {:ok, 4}
  end

  test "errors if function is not stubbed", %{stubr_server: stubr_server} do
    assert StubrServer.invoke(stubr_server, {:set, [2]}) == {:error, UndefinedFunctionError}
  end

  test "defers to module function if not stubbed", %{stubr_server: stubr_server} do
    assert StubrServer.set(stubr_server, :module, Float) == :ok
    assert StubrServer.invoke(stubr_server, {:ceil, [2.9]}) == {:ok, 3.0}
  end

  test "gets call info in order of calls", %{stubr_server: stubr_server} do
    assert StubrServer.add(stubr_server, :call_info, {:get, %{input: [0, 1, 2], output: 3}}) == :ok
    assert StubrServer.add(stubr_server, :call_info, {:get, %{input: [:foo, :bar], output: :baz}}) == :ok
    assert StubrServer.get(stubr_server, :call_info, :get) ==
      {:ok, [%{input: [0, 1, 2], output: 3}, %{input: [:foo, :bar], output: :baz}]}
  end

end
