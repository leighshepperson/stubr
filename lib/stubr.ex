defmodule Stubr do
  @name_generator Application.get_env(:stubr, :name_generator)

  defp create_args(_, 0),
    do: []
  defp create_args(module, amount),
    do: Enum.map(1..amount, &(Macro.var (:"arg#{&1}"), module))

  defmacro stub({function_name, function_impl}) do
     stub_name = @name_generator.generate()
     {function_eval, _} = function_impl |> Code.eval_quoted
     arity = (function_eval |> :erlang.fun_info)[:arity]
     args = create_args(:"Elixir.#{stub_name}", arity)

     content = quote bind_quoted: [function_name: function_name, function_impl: Macro.escape(function_impl), args: Macro.escape(args)] do
        def unquote(function_name)(unquote_splicing(args)) do
           unquote(function_impl).(unquote_splicing(args))
        end
      end

    {_, stub, _, _} = Module.create(:"Elixir.#{stub_name}", content, Macro.Env.location(__ENV__))

    stub
  end

end
