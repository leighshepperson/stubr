defmodule Stubr do
  @name_generator Application.get_env(:stubr, :name_generator)

  defmacro stub(function_reps) do
    content = function_reps |> create_content

    stub_name = @name_generator.generate()

    {_, stub, _, _} = Module.create(:"Elixir.#{stub_name}", content, Macro.Env.location(__ENV__))

    stub
  end

  defp create_content(function_reps) do
    function_reps = function_reps |> put_args

    quote bind_quoted: [function_reps: Macro.escape(function_reps)] do
      for {name, impl, args} <- function_reps do
        def unquote(name)(unquote_splicing(args)) do
          unquote(impl).(unquote_splicing(args))
        end
      end
    end
  end

  defp put_args({name, impl}),
    do: {name, impl, get_args(impl)}
  defp put_args(function_reps),
    do: function_reps |> Enum.map(&put_args(&1))

  defp get_args({:fn, [_], [{:->, [_], [args, _]}]}),
    do: args

end
