defmodule Stubr do
  @name_generator Application.get_env(:stubr, :name_generator)

  defp create_args(_, 0),
    do: []
  defp create_args(module, amount),
    do: Enum.map(1..amount, &(Macro.var (:"arg#{&1}"), module))

  defmacro stub({name, impl}) do
     unique_name = @name_generator.generate()
     args = create_args(:"Elixir.#{unique_name}", 2)
     content = quote bind_quoted: [name: name, impl: Macro.escape(impl), args: Macro.escape(args)] do
        def unquote(name)(unquote_splicing(args)) do
           unquote(impl).(unquote_splicing(args))
        end
      end

    {_, stub, _, _} = Module.create(:"Elixir.#{unique_name}", content, Macro.Env.location(__ENV__))

    stub
  end

end
