defmodule StubrAgentTest do
  use ExUnit.Case, async: true

  test "registers module by storing in map" do
    {:ok, pid} = StubrAgent.start_link
    assert :ok == StubrAgent.register_module(pid, String)
    assert Agent.get(pid, &(&1.module)) == String
  end

  test "registers function implementation by concatenating function implementations" do
    {:ok, pid} = StubrAgent.start_link
    foo = fn 1 -> 2 end
    bar = fn 2 -> 2 end
    assert :ok == StubrAgent.register_function(pid, {:first_function_name, foo})
    assert :ok == StubrAgent.register_function(pid, {:second_function_name, bar})
    assert Agent.get(pid, &(&1.function_impls)) == [{:first_function_name, foo}, {:second_function_name, bar}]
  end

  test "evaluates function implementation if it exists in function implementations" do
    foo = fn :ok -> :ok end
    bar = fn j -> j * 2 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}, {:second_function_name, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first_function_name, [a: :ok]}) == :ok
    assert StubrAgent.eval_function!(pid, {:second_function_name, [a: 2]}) == 4
  end

  test "evaluates an function as if it were pattern matched" do
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

  test "evaluates the first matching function" do
    foo = fn (_, _) -> :ok end
    bar = fn (1, 2) -> 3 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    refute StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}) == 3
    assert StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}) == :ok
  end

  test "If module is provided and no function_impls match then defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule Defer, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = Agent.start_link(fn ->
      %{module: Defer, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}) == 7
  end

  test "raises a FunctionClauseError if no function impl with valid params" do
    foo = fn :ok -> :ok end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}]}
    end)

    assert_raise FunctionClauseError, fn ->
      StubrAgent.eval_function!(pid, {:first_function_name, [a: :error]})
    end

  end

end
