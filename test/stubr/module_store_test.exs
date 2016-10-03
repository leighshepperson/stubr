defmodule ModuleSimulatorTest do
  use ExUnit.Case, async: true
  alias Stubr.ModuleStore

  test "sets a module implementation" do
    {:ok, pid} = ModuleStore.start_link

    module_implementation = [first: fn 1 -> 1 end, second: fn 2 -> 2 end]

    input = %{module_implementation: module_implementation}

    assert ModuleStore.set(pid, input) == :ok
    assert Agent.get(pid, &(&1)).module_implementation == module_implementation
  end

  test "sets a module" do
    {:ok, pid} = ModuleStore.start_link

    input = %{module: String}

    assert ModuleStore.set(pid, input) == :ok
    assert ModuleStore.get_module(pid) == String
  end

  test "gets function implementations" do
    foo = fn 1 -> 1 end
    bar = fn 2 -> 3 end
    baz = fn 2 -> 2 end

    input = %{module_implementation: [first: foo, first: bar, second: baz]}

    {:ok, pid} = ModuleStore.start_link
    ModuleStore.set(pid, input)

    assert ModuleStore.get_function_implementations(pid, :first) == [foo, bar]
    assert ModuleStore.get_function_implementations(pid, :second) == [baz]
  end

  test "sets the arguments and the output of a function" do
    {:ok, pid} = ModuleStore.start_link

    input = %{call_info: [get: [%{arguments: [1, 2, 3], output: 6}]]}

    assert ModuleStore.set(pid, input) == :ok
    assert ModuleStore.get_call_info(pid, :get) == [%{arguments: [1, 2, 3], output: 6}]
  end

  test "returns empty list if call info does not exist" do
    {:ok, pid} = ModuleStore.start_link

    assert ModuleStore.get_call_info(pid, :get) == []
  end

  test "sets the arguments and the output of a function in order of calls" do
    {:ok, pid} = ModuleStore.start_link

    input_one = %{call_info: [get: [%{arguments: [1, 2, 3], output: 6}]]}
    input_two = %{call_info: [get: [%{arguments: [3, 2, 1, :go], output: %{foo: :bar}}]]}
    input_three = %{call_info: [get: [%{arguments: [1], output: [1, 2, 3, 4]}]]}

    assert ModuleStore.set(pid, input_one) == :ok
    assert ModuleStore.set(pid, input_two) == :ok
    assert ModuleStore.set(pid, input_three) == :ok

    assert ModuleStore.get_call_info(pid, :get) == [
      %{arguments: [1, 2, 3], output: 6},
      %{arguments: [3, 2, 1, :go], output: %{foo: :bar}},
      %{arguments: [1], output: [1, 2, 3, 4]},
    ]
  end

  test "sets the arguments and the output of different functions in the order of calls" do
    {:ok, pid} = ModuleStore.start_link

    input_one = %{call_info: [get: [%{arguments: [1, 2, 3], output: 6}]]}
    input_two = %{call_info: [set: [%{arguments: [3, 2, 1, :go], output: %{foo: :bar}}]]}
    input_three = %{call_info: [save: [%{arguments: [1], output: [1, 2, 3, 4]}]]}
    input_four = %{call_info: [save: [%{arguments: [3, 2, 1, :go], output: %{foo: :bar}}]]}

    assert ModuleStore.set(pid, input_one) == :ok
    assert ModuleStore.set(pid, input_two) == :ok
    assert ModuleStore.set(pid, input_three) == :ok
    assert ModuleStore.set(pid, input_four) == :ok

    assert ModuleStore.get_call_info(pid, :get) == [
      %{arguments: [1, 2, 3], output: 6}]
    assert ModuleStore.get_call_info(pid, :set) == [
      %{arguments: [3, 2, 1, :go], output: %{foo: :bar}}]
    assert ModuleStore.get_call_info(pid, :save) == [
      %{arguments: [1], output: [1, 2, 3, 4]},
      %{arguments: [3, 2, 1, :go], output: %{foo: :bar}}
    ]
  end

end
