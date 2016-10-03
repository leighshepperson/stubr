defmodule Stubr.ModuleStore do
  @moduledoc false

  def start_link do
    Agent.start_link(fn -> %{module_implementation: [], module: nil, call_info: []} end)
  end

  def set(pid, new_state) do
    Agent.update(pid, fn old_state ->
      Map.merge(old_state, new_state, &merge_state(&1, &2, &3))
    end)
  end

  defp merge_state(:call_info, old_state, new_state) do
    Keyword.merge(old_state, new_state, fn _k, v1, [call_info] -> [call_info | v1] end)
  end

  defp merge_state(_, _, new_state), do: new_state

  def get_function_implementations(pid, function_name) do
    pid |> Agent.get(&Keyword.get_values(&1.module_implementation, function_name))
  end

  def get_module(pid) do
    Agent.get(pid, &(&1.module))
  end

  def get_call_info(pid, function_name) do
    case pid |> Agent.get(&Keyword.get_values(&1.call_info, function_name)) do
      [reverse_call_info] -> reverse_call_info |> Enum.reverse
      _ -> []
    end
  end

end