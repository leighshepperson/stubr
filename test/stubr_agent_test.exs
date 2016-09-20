defmodule StubrAgentTest do
  use ExUnit.Case, async: true

  test "It registers a module and function implementations" do
    {:ok, pid} = StubrAgent.start_link

    function_impls = [first: fn 1 -> 1 end, second: fn 2 -> 2 end]

    stubr = %{module: String, function_impls: function_impls}

    assert StubrAgent.register(pid, stubr) == :ok
    assert Agent.get(pid, &(&1)) == stubr
  end

  test "It evaluates a function implementation if it exists in function implementations" do
    foo = fn :ok -> :ok end
    bar = fn j -> j * 2 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}, {:second_function_name, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first_function_name, [a: :ok]}, nil) == :ok
    assert StubrAgent.eval_function!(pid, {:second_function_name, [a: 2]}, nil) == 4
  end

  test "It evaluates a function as if it were pattern matched" do
    foo = fn :ok -> :ok end
    bar = fn (1, 2) -> 3 end
    baz = fn %{map: value} -> 3 * value end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first, foo}, {:first, bar}, {:first, baz}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first, [a: :ok]}, nil) == :ok
    assert StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}, nil) == 3
    assert StubrAgent.eval_function!(pid, {:first, [a: %{map: 6}]}, nil) == 18
  end

  test "It evaluates the first matching function" do
    foo = fn (_, _) -> :ok end
    bar = fn (1, 2) -> 3 end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    refute StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}, nil) == 3
    assert StubrAgent.eval_function!(pid, {:first, [a: 1, b: 2]}, nil) == :ok
  end

  test "If a module is provided and no function implementations match and auto stub is true then defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule DeferTrue, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = Agent.start_link(fn ->
      %{module: DeferTrue, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    assert StubrAgent.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}, true) == 7
  end

  test "If a module is provided and no function implementations match and auto stub is false then do not defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule DeferFalse, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = Agent.start_link(fn ->
      %{module: DeferFalse, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    assert_raise FunctionClauseError, fn ->
      StubrAgent.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}, false)
    end
  end

  test "If a module is provided and no function implementations match and auto stub is nil then do not defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule DeferNil, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = Agent.start_link(fn ->
      %{module: DeferNil, function_impls: [{:first, foo}, {:first, bar}]}
    end)

    assert_raise FunctionClauseError, fn ->
      StubrAgent.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}, nil)
    end
  end

  test "Raises a FunctionClauseError if no function implementation exists with valid params" do
    foo = fn :ok -> :ok end

    {:ok, pid} = Agent.start_link(fn ->
      %{module: nil, function_impls: [{:first_function_name, foo}]}
    end)

    assert_raise FunctionClauseError, fn ->
      StubrAgent.eval_function!(pid, {:first_function_name, [a: :error]}, nil)
    end
  end

end
