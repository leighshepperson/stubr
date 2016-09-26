defmodule Stubr.ModuleRegister do
  @moduledoc false

  def start_link do
    Agent.start_link(fn -> %{module_implementation: [], module: nil} end)
  end

  def set_module(pid, %{module: module}) do
    Agent.update(pid, fn stubr -> %{stubr | module: module} end)
  end

  def set_module_implementation(pid, %{module_implementation: module_implementation}) do
    Agent.update(pid, fn stubr -> %{stubr | module_implementation: module_implementation} end)
  end

  def get_function_implementations(pid, function_name) do
    pid |> Agent.get(&Keyword.get_values(&1.module_implementation, function_name))
  end

  def get_module(pid) do
    Agent.get(pid, &(&1.module))
  end

end