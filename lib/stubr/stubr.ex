defmodule Stubr do
  alias Stubr.ModuleStore
  alias Stubr.ModuleSimulator

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
  def stub!(module, module_implementation, auto_stub: auto_stub),
    do: do_stub!(module, module_implementation, auto_stub)

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
  def stub!(module, module_implementation),
    do: do_stub!(module, module_implementation, false)

  @doc """
  Creates a stub using a list of function representations.

  ## Examples
      iex> Stubr.stub!([{:to_atom, fn ("foo") -> :stubbed end}]).to_atom("foo")
      :stubbed
  """
  @spec stub!([function_representation]) :: module | no_return
  def stub!(module_implementation),
    do: do_stub!(nil, module_implementation, nil)

  defp do_stub!(module, module_implementation, auto_stub) do
    case can_stub?(module, module_implementation) do
      true -> :ok
      false -> raise UndefinedFunctionError
    end

    create_module(module, module_implementation, auto_stub)
  end

  defp create_module(module, module_implementation, true) do
    create_module(module, module_implementation)
  end

  defp create_module(_, module_implementation, _) do
    create_module(nil, module_implementation)
  end

  defp create_module(module, module_implementation) do
    {:ok, pid} = ModuleStore.start_link

    :ok = ModuleStore.set(pid, %{module: module, module_implementation: module_implementation})

    body = create_body(pid, get_args(module, module_implementation))

    module_name = create_module_name()

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp create_body(pid, args) do
    quote bind_quoted: [args: Macro.escape(args), pid: pid] do
      def __stubr__(call_info: call_info) do
        ModuleStore.get_call_info(unquote(pid), call_info)
      end

      for {name, args} <- args do
        def unquote(name)(unquote_splicing(args)) do
          ModuleSimulator.eval_function!(unquote(pid), {unquote(name), binding()})
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

  defp can_stub?(nil, _) do
    true
  end

  defp can_stub?(module, module_implementation) do
    module_arities = MapSet.new(module.module_info(:functions))
    function_impl_arities = MapSet.new(get_arities(module_implementation))

    MapSet.union(module_arities, function_impl_arities) == module_arities
  end

  defp get_args(nil, module_implementation) do
    for {name, function_impl} <- module_implementation do
      {name, create_args(:erlang.fun_info(function_impl)[:arity])}
    end
  end

  defp get_args(module, _) do
    for {name, arity} <- module.__info__(:functions) do
      {name, create_args(arity)}
    end
  end

  defp create_args(arity) do
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

  defp get_arities(module_implementation) do
    for {name, function_impl} <- module_implementation do
      {name, :erlang.fun_info(function_impl)[:arity]}
    end
  end

end
