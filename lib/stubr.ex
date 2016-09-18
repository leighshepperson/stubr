defmodule Stubr do
  @moduledoc """
  Provides a set of functions to stub modules.

      iex> Stubr.stub([{:get, fn i -> i end}]).get(:ok)
      :ok

  The stub function creates a new module with a random name under the
  Stubr namespace. This is to stop collisions with other modules.
  It generates stubs by passing in a list of function representations.
  A function representation takes the following form:

      {:function_name, (... -> any())}

  The stub function can create stubs with functions of different arity,
  argument patterns and names.

  Stubs behave in the expected way:

      stubbed = Stubr.stub([{:add, fn(i, j) -> i + j end}])

      stubbed.add(1, 2) = 3

  Additionally, the first argument of the stub function is an optional
  module. This is used to stop it from creating stubs of undefined
  functions.
  """

  @typedoc """
  This is a representation of a function. The first element is the
  function name atom. The second element is an anonymous function.
  This defines the behaviour of the function.
  """
  @type function_representation :: {atom, (... -> any)}

  @doc """
  Creates a stub. The module argument prevents the creation of
  invalid stubs. It should return a new module. The function
  representations define its functions. Returns an
  `UndefinedFunctionError` if given invalid function representations.

  ## Examples
      iex> Stubr.stub(String, [{:to_atom, fn ("hello") -> :hello end}]).to_atom("hello")
      :hello
  """
  @spec stub(module, [function_representation]) :: module | no_return
  def stub(module, function_reps) do
    {:ok} = is_defined!(module, function_reps)
    stub(function_reps)
  end

  @doc """
  Creates a stub. It returns a new module. The function
  representations define its functions.

  ## Examples
      iex> Stubr.stub([{:add, fn (i, 2) -> i + 2 end}]).add(3, 2)
      5
  """
  @spec stub([function_representation]) :: module | no_return
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
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

end
