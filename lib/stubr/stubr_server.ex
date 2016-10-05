defmodule StubrServer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def invoke(pid, {function_name, arguments}) do
    GenServer.call(pid, {:invoke, function_name, arguments})
  end

  def add(pid, :function, {function_name, implementation}) do
    GenServer.cast(pid, {:add_function, {function_name, implementation}})
  end

  def set(pid, :module, module) do
    GenServer.cast(pid, {:set_module, module})
  end

  def init(:ok) do
    {:ok, %{functions: [], module: nil}}
  end

  def handle_call({:invoke, function_name, arguments}, _, %{module: nil} = state) do
    result = invoke_function(function_name, arguments, state)

    {:reply, result, state}
  end

  def handle_call({:invoke, function_name, arguments}, _, state) do
    result = function_name
    |> invoke_function(arguments, state)
    |> defer_on_error(function_name, arguments, state)

    {:reply, result, state}
  end

  def handle_cast({:add_function, {function_name, implementation}}, state) do
    {:noreply, %{state | functions: state.functions ++ [{function_name, implementation}]}}
  end

  def handle_cast({:set_module, module}, state) do
    {:noreply, %{state | module: module}}
  end

  defp invoke_function(function_name, arguments, %{functions: functions}) do
    implementations = functions
    |> Keyword.get_values(function_name)

    implementations
    |> Enum.reduce_while({:error, UndefinedFunctionError}, fn implementation, _acc ->
      try do
        {:halt, {:ok, apply(implementation, arguments)}}
      rescue
        error -> {:cont, {:error, error}}
      end
    end)
  end

  defp defer_on_error({:error, _}, function_name, arguments, %{module: module}) do
    try do
      {:ok, apply(module, function_name, arguments)}
    rescue
      error -> {:error, error}
    end
  end

  defp defer_on_error(result, _, _, _) do
    result
  end

end