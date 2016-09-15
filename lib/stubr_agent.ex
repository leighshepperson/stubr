defmodule StubrAgent do

  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def register_function(pid, {name, function}) do
    Agent.update(pid, &(&1 ++ [{name, function}]))
  end

  def eval_function(pid, {name, args}) do
    params = args
    |> Enum.map(fn({_, values}) -> values end)

    pid
    |> Agent.get(&Keyword.get_values(&1, name))
    |> eval_functions(params)
  end

  defp eval_functions([], _),
    do: raise FunctionClauseError
  defp eval_functions([function|functions], params) do
    try do
      apply(function, params)
    rescue
      _ in FunctionClauseError -> eval_functions(functions, params)
    end
  end

end