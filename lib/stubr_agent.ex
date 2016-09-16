defmodule StubrAgent do

  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def register_function(pid, {function_name, function_impl}) do
    Agent.update(pid, &(&1 ++ [{function_name, function_impl}]))
  end

  def eval_function(pid, {function_name, arg_list}) do
    args = arg_list
    |> Enum.map(fn({_, arg}) -> arg end)

    pid
    |> Agent.get(&Keyword.get_values(&1, function_name))
    |> eval_functions(args, nil)
  end

  defp eval_functions([], _, error),
    do: raise error
  defp eval_functions([function_impl|function_impls], args, _) do
    try do
      apply(function_impl, args)
    rescue
      error -> eval_functions(function_impls, args, error)
    end
  end

end