defmodule Stubr do
  @moduledoc """
  Framework used to stub modules and provide canned answers during a test.

  The `Stubr.stub/2` function accepts a module argument and a list of function
  representations. For example, the expression

    Stubr.stub(HTTPoison, [
      {:get, fn(url) -> {:ok, %HTTPoison.Response{status_code: 500}}}
    ])

  creates a module that returns a HTTPoison.Response struct when it invokes
  the `XXX.get/1` function.

  If the HTTPoison module does not contain the function `HTTPoison.get/1`,
  then Stubr raises an `UndefinedFunctionError`.

  The module name of the stub created by Stubr is a random string to ensure
  it does not redefine existing modules.

  Additionally, `Stubr.stub/1` creates stubs with arbitary function
  representations.
  """

  @doc ~S"""
  Creates a new module that stubs specified functions in the given module

  ## Examples
      iex> defmodule Foo, do: def test(1), do: :ok
      iex> Stubr.stub(Foo, [{:test, fn(_) -> :good_bye end}]).test(1)
      :good_bye

  """
  @spec stub(module(), [{atom(), (t::any() -> any())}]) :: module() | Error
  def stub(module, function_reps) do
    {:ok} = is_defined!(module, function_reps)
    stub(function_reps)
  end

  @doc ~S"""
  Creates a new module for stubbing defined by provided functions

  ## Examples
      iex> Stubr.stub([{:foo, fn(1, 2, 3) -> :bar end}]).foo(1, 2, 3)
      :bar

  """
  @spec stub([{atom(), (t::any() -> any())}]) :: module() | Error
  def stub(function_reps) do
    {:ok, pid} = StubrAgent.start_link

    function_reps
    |> Enum.each(&StubrAgent.register_function(pid, &1))

    function_reps
    |> create_body(pid)
    |> create_module
  end

  defp is_defined!(module, function_reps) do
    module_function_set = MapSet.new(module.module_info(:functions))

    for {name, impl} <- function_reps do
      if !MapSet.member?(module_function_set, {name, :erlang.fun_info(impl)[:arity]}) do
        raise UndefinedFunctionError
      end
    end

    {:ok}
  end

  defp create_body(function_reps, pid) do
    function_args = function_reps |> get_args

    quote bind_quoted: [function_args: Macro.escape(function_args), pid: pid] do
      for {name, args} <- function_args do
        def unquote(name)(unquote_splicing(args)) do
          StubrAgent.eval_function(unquote(pid), {unquote(name), binding()})
        end
      end
    end
  end

  defp create_module(body) do
    random_string = (for _ <- 1..32, do: :rand.uniform(26) + 96)

    module_name = random_string
    |> to_string
    |> String.capitalize

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp get_args({name, function}),
    do: {name, create_args(function)}
  defp get_args(functions_reps),
    do: functions_reps |> Enum.map(&get_args(&1))

  defp create_args(function) do
    arity = (function |> :erlang.fun_info)[:arity]
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

end
