defmodule Stubr do
  defmacro stub(functions) do
    functions
    |> create_body
    |> create_module
  end

  defp create_module(body) do
    module_name = for _ <- 1..64, do: :rand.uniform(26) + 96
    |> to_string
    |> String.capitalize

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp create_body(functions) do
    functions = functions |> put_args

    quote bind_quoted: [functions: Macro.escape(functions)] do
      for {name, impl, args} <- functions do
        def unquote(name)(unquote_splicing(args)) do
          unquote(impl).(unquote_splicing(args))
        end
      end
    end
  end

  defp put_args({name, impl}),
    do: {name, impl, get_args(impl)}
  defp put_args(functions),
    do: functions |> Enum.map(&put_args(&1))

  defp get_args({:fn, [_], [{:->, [_], [args, _]}]}),
    do: args

end
