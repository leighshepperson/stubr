defmodule StubrAgentTest do
  use ExUnit.Case, async: true

  test "It registers provided module and function implementations" do
    {:ok, pid} = StubrAgent.start_link

    function_impls = [first: fn 1 -> 1 end, second: fn 2 -> 2 end]

    stubr = %{module: String, function_impls: function_impls}

    assert StubrAgent.register(pid, stubr) == :ok
    assert Agent.get(pid, &(&1)) == stubr
  end

  test "It applies a function implementation to binding values if it exists" do
    foo = fn :ok -> :ok end
    bar = fn j -> j * 2 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}, {:second_function_name, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first_function_name, [a: :ok]}) == :ok
    assert StubrAgent.eval_function!(pid, {:second_function_name, [a: 2]}) == 4
  end

  test "It evaluates a function in pattern matched order" do
    foo = fn :ok -> :ok end
    bar = fn (1, 2) -> 3 end
    baz = fn %{map: value} -> 3 * value end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first, foo}, {:first, bar}, {:first, baz}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first, [a: :ok]}) == :ok
    assert StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}) == 3
    assert StubrAgent.eval_function!(pid, {:first, [a: %{map: 6}]}) == 18
  end

  test "It evaluates the first function that matches the pattern" do
    foo = fn (_, _) -> :ok end
    bar = fn (1, 2) -> 3 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    refute StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}) == 3
    assert StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}) == :ok
  end

  test "If a module is provided and no function implementations match then defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule DeferTrue, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = Agent.start_link(fn ->
      %{module: DeferTrue, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}) == 7
  end

  test "It raises a FunctionClauseError if no function implementation exists with valid params" do
    foo = fn :ok -> :ok end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}]}
    end)

    assert_raise FunctionClauseError, fn ->
      StubrAgent.eval_function!(pid, {:first_function_name, [a: :error]})
    end
  end

end
