defmodule Stubr do
  @name_generator Application.get_env(:stubr, :name_generator)

  defmacro stub(functions) do

     body = functions |> create_body

     stub_name = @name_generator.generate()

    {_, stub, _, _} = Module.create(:"Elixir.#{stub_name}", body, Macro.Env.location(__ENV__))

    stub
  end

  defp create_body(functions) do
    functions_with_args = functions |> get_args

    quote bind_quoted: [functions_with_args: Macro.escape(functions_with_args)] do
      for {name, impl, args} <- functions_with_args do
        def unquote(name)(unquote_splicing(args)) do
          unquote(impl).(unquote_splicing(args))
        end
      end
    end
  end

  defp get_args(functions) when is_list(functions),
    do: functions |> Enum.map(&get_args(&1))
  defp get_args({name, impl}),
    do: {name, impl, get_args(impl)}
  defp get_args({:fn, [_], [{:->, [_], [args, _]}]}),
    do: args

end
