defmodule ModuleSimulatorTest do
  use ExUnit.Case, async: true
  alias Stubr.ModuleRegister

  test "sets a module implementation" do
    {:ok, pid} = ModuleRegister.start_link

    module_implementation = [first: fn 1 -> 1 end, second: fn 2 -> 2 end]

    input = %{module_implementation: module_implementation}

    assert ModuleRegister.set_module_implementation(pid, input) == :ok
    assert Agent.get(pid, &(&1)).module_implementation == module_implementation
  end

  test "sets a module" do
    {:ok, pid} = ModuleRegister.start_link

    input = %{module: String}

    assert ModuleRegister.set_module(pid, input) == :ok
    assert ModuleRegister.get_module(pid) == String
  end

  test "gets function implementations" do
    foo = fn 1 -> 1 end
    bar = fn 2 -> 3 end
    baz = fn 2 -> 2 end

    input = %{module_implementation: [first: foo, first: bar, second: baz]}

    {:ok, pid} = ModuleRegister.start_link
    ModuleRegister.set_module_implementation(pid, input)

    assert ModuleRegister.get_function_implementations(pid, :first) == [foo, bar]
    assert ModuleRegister.get_function_implementations(pid, :second) == [baz]
  end

end
