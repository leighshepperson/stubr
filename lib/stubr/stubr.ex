defmodule Stubr do
  @defaults [auto_stub: false, module: nil, behaviour: nil]

  def stub!(functions, opts \\ []) do
    %{auto_stub: auto_stub, module: module, behaviour: behaviour} = @defaults
    |> Keyword.merge(opts)
    |> Enum.into(%{})

    {:ok} = can_stub!(module, functions)

    {:ok, pid} = add_functions_to_server(functions)

    if auto_stub do
      do_auto_stub!(pid, module, behaviour)
    else
      do_stub!(pid, functions, behaviour)
    end
  end

  defp do_stub!(pid, functions, behaviour) do
    args_for_functions = for {function_name, implementation} <- functions do
      {function_name, create_args(:erlang.fun_info(implementation)[:arity])}
    end

    create_module(pid, args_for_functions, behaviour)
  end

  defp do_auto_stub!(pid, module, behaviour) do
    StubrServer.set(pid, :module, module)

    args_for_module_functions = for {function_name, arity} <- module.__info__(:functions) do
      {function_name, create_args(arity)}
    end

    create_module(pid, args_for_module_functions, behaviour)
  end

  defp add_functions_to_server(functions) do
    {:ok, pid} = StubrServer.start_link

    for {function_name, implementation} <- functions do
      StubrServer.add(pid, :function, {function_name, implementation})
    end

    {:ok, pid}
  end

  defp create_module(pid, args_for_functions, behaviour) do
    body = create_body(pid, args_for_functions, behaviour)

    module_name = create_module_name()

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp create_body(pid, args_for_functions, behaviour) do
    quote bind_quoted: [args_for_functions: Macro.escape(args_for_functions), pid: pid, behaviour: behaviour] do
      if behaviour != nil do
        @behaviour behaviour
      end

      def __stubr__(call_info: function_name) do
        {:ok, call_info} = StubrServer.get(unquote(pid), :call_info, function_name)
        call_info
      end

      for {function_name, args_for_function} <- args_for_functions do
        def unquote(function_name)(unquote_splicing(args_for_function)) do
          variable_values = for {_, variable_value} <- binding, do: variable_value

          {success_atom, output} = StubrServer.invoke(unquote(pid), {unquote(function_name), variable_values})

          StubrServer.add(unquote(pid), :call_info, {unquote(function_name), %{input: variable_values, output: output}})

          case {success_atom, output} do
            {:ok, result} -> result
            {:error, error} -> raise error
          end
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

  defp create_args(arity) do
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

  defp can_stub!(nil, _) do
    {:ok}
  end

  defp can_stub!(module, functions) do
    arities_for_functions = for {function_name, implementation} <- functions do
      {function_name, :erlang.fun_info(implementation)[:arity]}
    end

    case (arities_for_functions |> Enum.uniq) -- module.module_info(:functions) do
      [] -> {:ok}
      _ -> raise UndefinedFunctionError
    end
  end

end
