defmodule StubrAgent do
  @moduledoc false

  def start_link do
    Agent.start_link(fn -> %{functions: [], module: nil} end)
  end

  def register_module(pid, module) do
    Agent.update(pid, fn state -> %{state | module: module} end)
  end

  def register_function(pid, {function_name, function_impl}) do
    Agent.update(pid,
      fn %{functions: functions} = state -> %{state | functions: functions ++ [{function_name, function_impl}] }
      end)
  end

  def eval_function(pid, {function_name, arg_list}) do
    args = arg_list
    |> Enum.map(fn({_, arg}) -> arg end)

    module = pid |> Agent.get(&(&1.module))
    pid
    |> Agent.get(&Keyword.get_values(&1.functions, function_name))
    |> eval_functions(args, nil, module, function_name)
  end

  defp eval_functions([], args, error, module, function_name) do
    case module do
      nil -> raise error
      _ -> apply(module, function_name, args)
    end
  end
  defp eval_functions([function_impl|function_impls], args, _, module, function_name) do
    try do
      apply(function_impl, args)
    rescue
      error -> eval_functions(function_impls, args, error, module, function_name)
    end
  end

end