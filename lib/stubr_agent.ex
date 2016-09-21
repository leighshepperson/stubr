defmodule StubrAgent do
  @moduledoc false

  def start_link do
    Agent.start_link(fn -> %{function_impls: [], module: nil} end)
  end

  def register(pid, %{function_impls: function_impls, module: module}) do
    Agent.update(pid, fn stubr -> %{stubr | function_impls: function_impls, module: module} end)
  end

  def eval_function!(pid, {function_name, binding}) do
    variable_values = for {_, variable_value} <- binding, do: variable_value

    function_impls = pid
    |> Agent.get(&Keyword.get_values(&1.function_impls, function_name))

    try do
      eval_function_impls!(function_impls, variable_values, nil)
    rescue
      error -> defer_to_module!(Agent.get(pid, &(&1.module)), function_name, variable_values, error)
    end
  end

  defp defer_to_module!(nil, _, _, error),
    do: raise error
  defp defer_to_module!(module, function_name, variable_values, _),
    do: apply(module, function_name, variable_values)

  defp eval_function_impls!([], _, error),
    do: raise error
  defp eval_function_impls!([function_impl|function_impls], variable_values, _) do
    try do
      apply(function_impl, variable_values)
    rescue
      error -> eval_function_impls!(function_impls, variable_values, error)
    end
  end

end