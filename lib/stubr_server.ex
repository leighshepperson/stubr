defmodule StubrServer do
  @moduledoc false
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

  def add(pid, :call_info, {function_name, %{input: input, output: output}}) do
    GenServer.cast(pid, {:add_call_info, {function_name, %{input: input, output: output}}})
  end

  def set(pid, :module, module) do
    GenServer.cast(pid, {:set_module, module})
  end

  def get(pid, :call_info, function_name) do
    GenServer.call(pid, {:get_call_info, function_name})
  end

  def init(:ok) do
    {:ok, %{functions: [], module: nil, call_info: []}}
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

  def handle_call({:get_call_info, function_name}, _, state) do
    result = state.call_info |> Keyword.get(function_name)

    {:reply, {:ok, result}, state}
  end

  def handle_cast({:add_function, {function_name, implementation}}, state) do
    {:noreply, %{state | functions: state.functions ++ [{function_name, implementation}]}}
  end

  def handle_cast({:set_module, module}, state) do
    {:noreply, %{state | module: module}}
  end

  def handle_cast({:add_call_info, {function_name, %{input: _, output: _} = function_call_info}}, state) do
    call_info = state.call_info
    |> Keyword.update(function_name, [function_call_info], &(&1 ++ [function_call_info]))

    {:noreply, %{state | call_info: call_info}}
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

  defp defer_on_error(result, _, _, %{module: nil}) do
    result
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
