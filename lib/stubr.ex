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
  Creates a stub using a list of function representations.

  The module argument prevents the creation of invalid stubs by
  checking if the function representations are defined for that
  module. Otherwise, it returns an `UndefinedFunctionError`.

  If the auto_stub option is set to true, then it will defer all
  un-stubbed functions to the original module.

  ## Examples
      iex> Stubr.stub!(String, [{:to_atom, fn ("foo") -> :stubbed end}]).to_atom("foo")
      :stubbed
      iex> Stubr.stub!(String, [{:to_atom, fn ("foo") -> :stubbed end}], auto_stub: true).to_atom("bar")
      :bar
  """
  @spec stub!(module, [function_representation], [auto_stub: boolean]) :: module | no_return
  def stub!(module, function_impls, auto_stub: auto_stub),
    do: do_stub!(module, function_impls, auto_stub)

  @doc """
  Creates a stub using a list of function representations.

  The module argument prevents the creation of invalid stubs by
  checking if the function representations are defined for that
  module. Otherwise, it returns an `UndefinedFunctionError`.

  ## Examples
      iex> Stubr.stub!(String, [{:to_atom, fn ("foo") -> :stubbed end}]).to_atom("foo")
      :stubbed
  """
  @spec stub!(module, [function_representation]) :: module | no_return
  def stub!(module, function_impls),
    do: do_stub!(module, function_impls, false)

  @doc """
  Creates a stub using a list of function representations.

  ## Examples
      iex> Stubr.stub!([{:to_atom, fn ("foo") -> :stubbed end}]).to_atom("foo")
      :stubbed
  """
  @spec stub!([function_representation]) :: module | no_return
  def stub!(function_impls),
    do: do_stub!(nil, function_impls, nil)

  defp do_stub!(module, function_impls, auto_stub) do
    :ok = can_stub!(module, function_impls)

    pid = register(module, function_impls)
    arities = get_arities(module, function_impls, auto_stub)

    arities
    |> create_args
    |> create_body(pid, auto_stub)
    |> create_module
  end

  defp create_args({name, arity}),
    do: {name, Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))}
  defp create_args(function_impls),
    do: function_impls |> Enum.map(&create_args(&1))

  defp create_body(args, pid, auto_stub) do
    quote bind_quoted: [args: Macro.escape(args), pid: pid, auto_stub: auto_stub] do
      for {name, args} <- args do
        def unquote(name)(unquote_splicing(args)) do
          StubrAgent.eval_function!(unquote(pid), {unquote(name), binding()}, unquote(auto_stub))
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

  defp register(module, function_impls) do
    {:ok, pid} = StubrAgent.start_link
    StubrAgent.register(pid, %{module: module, function_impls: function_impls})
    pid
  end

  defp can_stub!(nil, _) do
    :ok
  end

  defp can_stub!(module, function_impls) do
    module_functions_set = MapSet.new(module.module_info(:functions))
    functions_set = MapSet.new(get_arities(function_impls))

    case MapSet.union(module_functions_set, functions_set) == module_functions_set do
      true -> :ok
      false -> raise UndefinedFunctionError
    end
  end

  defp get_arities(module, _, true) do
    module.__info__(:functions)
  end

  defp get_arities(_, function_impls, _) do
    get_arities(function_impls)
  end

  defp get_arities(function_impls) do
    function_impls |> Enum.map(fn{name, function} ->
      {name, :erlang.fun_info(function)[:arity]}
    end)
  end

end
