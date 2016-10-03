defmodule Stubr.ModuleSimulator do
  alias Stubr.ModuleStore
  @moduledoc false

  def eval_function!(pid, {function_name, binding}) do
    variable_values = for {_, variable_value} <- binding, do: variable_value

    function_implementations = ModuleStore.get_function_implementations(pid, function_name)

    output =
      try do
        eval_function_implementations!(function_implementations, variable_values, nil)
      rescue
        error -> defer_to_module!(ModuleStore.get_module(pid), function_name, variable_values, error)
      end

    ModuleStore.set(pid, %{call_info: [{function_name, [%{arguments: variable_values, output: output}]}]})

    output
  end

  defp defer_to_module!(nil, _, _, error),
    do: raise error
  defp defer_to_module!(module, function_name, variable_values, _),
    do: apply(module, function_name, variable_values)

  defp eval_function_implementations!([], _, error),
    do: raise error
  defp eval_function_implementations!([function_implementation|function_implementations], variable_values, _) do
    try do
      apply(function_implementation, variable_values)
    rescue
      error -> eval_function_implementations!(function_implementations, variable_values, error)
    end
  end

end