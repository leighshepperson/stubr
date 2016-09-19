defmodule Stubr do
  @moduledoc """
  This module contains functions that create stub modules.

  The functions `stub/1` and `stub/2` create new modules based on
  a list of function representations.

  The function `stub/2` also accepts a module as an optional
  first parameter. In this case, it checks whether the function(s)
  you want to stub exist in that module. Otherwise, it raises an
  `UndefinedFunctionError`.
  """

  @typedoc """
  Represents a function name
  """
  @type function_name :: atom

  @typedoc """
  Represents a function. The first element is an atom that represents
  the function name. The second element is an anonymous function that
  defines the behaviour of the function
  """
  @type function_representation :: {function_name, (... -> any)}

  @doc """
  Creates a stub using a list of function representations and a
  module to check for function existance.

  The module argument prevents the creation of invalid stubs by
  checking if the function representations are defined for that
  module. Otherwise, it returns an `UndefinedFunctionError`.

  ## Examples
      iex> Stubr.stub(String, [{:to_atom, fn ("hello") -> :hello end}]).to_atom("hello")
      :hello
  """
  @spec stub(module, [function_representation]) :: module | no_return
  def stub(module, function_reps) do
    {:ok} = is_defined!(module, function_reps)
    do_stub(module, function_reps)
  end

  @doc """
  Creates a stub using a list of function representations.

  ## Examples
      iex> Stubr.stub([{:add, fn (i, 2) -> i + 2 end}]).add(3, 2)
      5
  """
  @spec stub([function_representation]) :: module | no_return
  def stub(function_reps) do
    do_stub(nil, function_reps)
  end

  defp do_stub(module, function_reps) do
    {:ok, pid} = StubrAgent.start_link

    function_reps
    |> Enum.each(&StubrAgent.register_function(pid, &1))

    function_args =    function_reps
    |> get_args

    if !(module == nil) do
    function_args = module.__info__(:functions)
    |> Enum.map(fn{k, v} -> {k, create_args_arity(v)} end)

    StubrAgent.register_module(pid, module)
  end


    function_args
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

  defp create_body(function_args, pid) do
    quote bind_quoted: [function_args: Macro.escape(function_args), pid: pid] do
      for {name, args} <- function_args do
        def unquote(name)(unquote_splicing(args)) do
          StubrAgent.eval_function(unquote(pid), {unquote(name), binding()})
        end
      end
    end
  end

  defp create_module(body) do
    random_char_list = (for _ <- 1..32, do: :rand.uniform(26) + 96)

    module_name = random_char_list
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
    create_args_arity(arity)
  end

  defp create_args_arity(arity) do
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

end
