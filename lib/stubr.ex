defmodule Stubr do
  @moduledoc """
  This module contains functions that create stub modules.

  The functions `stub/1` and `stub/2` create new modules based on
  a list of function representations.

  The function `stub/2` also accepts a module as an optional
  first parameter. In this case, it checks whether the function(s)
  you want to stub exist in that module. Otherwise, it raises an
  `UndefinedFunctionError`. Additionally, if the auto_stub option
  is set to true, then it will defer all un-stubbed functions
  to the original module.
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
    case can_stub?(module, function_impls) do
      true -> :ok
      false -> raise UndefinedFunctionError
    end

    create_module(module, function_impls, auto_stub)
  end

  defp create_module(module, function_impls, auto_stub) do
    {:ok, pid} = StubrAgent.start_link

    :ok = register(pid, module, function_impls, auto_stub)

    body = create_body(pid, get_args(module, function_impls, auto_stub))

    module_name = create_module_name()

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp create_body(pid, args) do
    quote bind_quoted: [args: Macro.escape(args), pid: pid] do
      for {name, args} <- args do
        def unquote(name)(unquote_splicing(args)) do
          StubrAgent.eval_function!(unquote(pid), {unquote(name), binding()})
        end
      end
    end
  end

  defp create_module_name do
    random_char_list = (for _ <- 1..32, do: :rand.uniform(26) + 96)

    random_char_list
    |> to_string
    |> String.capitalize
  end

  defp register(pid, module, function_impls, true) do
    StubrAgent.register(pid, %{module: module, function_impls: function_impls})
  end

  defp register(pid, module, function_impls, _) do
    StubrAgent.register(pid, %{module: nil, function_impls: function_impls})
  end

  defp can_stub?(nil, _) do
    true
  end

  defp can_stub?(module, function_impls) do
    module_arities = MapSet.new(module.module_info(:functions))
    function_impl_arities = MapSet.new(get_arities(function_impls))

    MapSet.union(module_arities, function_impl_arities) == module_arities
  end

  defp get_args(module, _, true) do
    for {name, arity} <- module.__info__(:functions) do
      {name, create_args(arity)}
    end
  end

  defp get_args(_, function_impls, _) do
    for {name, function_impl} <- function_impls do
      {name, create_args(:erlang.fun_info(function_impl)[:arity])}
    end
  end

  defp create_args(arity) do
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

  defp get_arities(function_impls) do
    for {name, function_impl} <- function_impls do
      {name, :erlang.fun_info(function_impl)[:arity]}
    end
  end

end
