defmodule ModuleStoreTest do
  use ExUnit.Case, async: true
  alias Stubr.ModuleSimulator
  alias Stubr.ModuleStore

  test "It applies a function implementation to binding values if it exists" do
    foo = fn :ok -> :ok end
    bar = fn j -> j * 2 end

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}, {:second, bar}]}
    )

    assert ModuleSimulator.eval_function!(pid, {:first, [a: :ok]}) == :ok
    assert ModuleSimulator.eval_function!(pid, {:second, [a: 2]}) == 4
  end

  test "It evaluates a function in order of overloads" do
    foo = fn :ok -> :ok end
    bar = fn (1, 2) -> 3 end
    baz = fn %{map: value} -> 3 * value end

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}, {:first, bar}, {:first, baz}]}
    )

    assert ModuleSimulator.eval_function!(pid, {:first, [a: :ok]}) == :ok
    assert ModuleSimulator.eval_function!(pid, {:first, [a: 1, b: 2]}) == 3
    assert ModuleSimulator.eval_function!(pid, {:first, [a: %{map: 6}]}) == 18
  end

  test "It evaluates the first function that matches the pattern" do
    foo = fn (_, _) -> :ok end
    bar = fn (1, 2) -> 3 end

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}, {:first, bar}]}
    )

    refute ModuleSimulator.eval_function!(pid, {:first, [a: 1, b: 2]}) == 3
    assert ModuleSimulator.eval_function!(pid, {:first, [a: 1, b: 2]}) == :ok
  end

  test "If a module is provided and no function implementations match then defer to module" do
    foo = fn (2, 4, 2) -> :ok end
    bar = fn (1, 2, 9) -> 3 end

    defmodule DeferTrue, do: def first(x, y, z), do: x + y + z

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}, {:first, bar}]}
    )

    ModuleStore.set(pid, %{module: DeferTrue})

    assert ModuleSimulator.eval_function!(pid, {:first, [a: 2, b: 4, c: 1]}) == 7
  end

  test "It raises a FunctionClauseError if no function implementation exists with valid params" do
    foo = fn :ok -> :ok end

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}]}
    )

    assert_raise FunctionClauseError, fn ->
      ModuleSimulator.eval_function!(pid, {:first, [a: :error]})
    end
  end

  test "If a function is called, then it saves the call info" do
    foo = fn :ok -> :ok end

    {:ok, pid} = ModuleStore.start_link

    ModuleStore.set(
      pid, %{module_implementation: [{:first, foo}]}
    )

    ModuleSimulator.eval_function!(pid, {:first, [a: :ok]})

    assert ModuleStore.get_call_info(pid, :first) == [%{arguments: [:ok], output: :ok}]
  end

end
