defmodule Stubr.Stub do
  @moduledoc false
  @auto_stub Application.get_env(:stubr, :auto_stub) || false
  @call_info Application.get_env(:stubr, :call_info) || false
  @defaults [auto_stub: @auto_stub, module: nil, behaviour: nil, call_info: @call_info]

  def create!(functions, opts \\ []) do
    opts = @defaults
    |> Keyword.merge(opts)
    |> Enum.into(%{})

    {:ok} = can_stub!(functions, opts)

    {:ok, pid} = add_functions_to_server(functions)

    do_stub(pid, functions, opts)
  end

  defp do_stub(pid, _, %{auto_stub: true, module: module} = opts) do
    StubrServer.set(pid, :module, module)

    args_for_module_functions = for {function_name, arity} <- module.__info__(:functions) do
      {function_name, create_args(arity)}
    end

    create_stub(pid, args_for_module_functions, opts)
  end

  defp do_stub(pid, functions, opts) do
    args_for_functions = for {function_name, implementation} <- functions do
      {function_name, create_args(:erlang.fun_info(implementation)[:arity])}
    end

    create_stub(pid, args_for_functions, opts)
  end

  defp add_functions_to_server(functions) do
    {:ok, pid} = StubrServer.start_link

    for {function_name, implementation} <- functions do
      StubrServer.add(pid, :function, {function_name, implementation})
    end

    {:ok, pid}
  end

  defp create_stub(pid, args, opts) do
    pid
    |> create_body(args, opts)
    |> create_module
  end

  defp create_module(body) do
    module_name = create_module_name()

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp create_body(pid, args_for_functions, %{behaviour: behaviour, call_info: call_info}) do
    quote bind_quoted: [
      args_for_functions: Macro.escape(args_for_functions),
      pid: pid,
      behaviour: behaviour,
      call_info_option: call_info
    ]
    do
      if behaviour != nil, do: @behaviour behaviour

      def __stubr__(call_info: function_name) do
        if unquote(call_info_option) do
          {:ok, call_info} = StubrServer.get(unquote(pid), :call_info, function_name)
          call_info
        else
          []
        end
      end

      for {function_name, args_for_function} <- args_for_functions do
        def unquote(function_name)(unquote_splicing(args_for_function)) do
          variable_values = for {_, variable_value} <- binding(), do: variable_value

          {success_atom, output} = StubrServer.invoke(unquote(pid), {unquote(function_name), variable_values})

          if unquote(call_info_option) do
            StubrServer.add(unquote(pid), :call_info, {unquote(function_name), %{input: variable_values, output: output}})
          end

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

  defp create_args(0),
    do: []
  defp create_args(arity) do
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

  defp can_stub!(_, %{module: nil}) do
    {:ok}
  end

  defp can_stub!(functions, %{module: module}) do
    arities_for_functions = for {function_name, implementation} <- functions do
      {function_name, :erlang.fun_info(implementation)[:arity]}
    end

    case (arities_for_functions |> Enum.uniq) -- module.module_info(:functions) do
      [] -> {:ok}
      _ -> raise UndefinedFunctionError
    end
  end

end
