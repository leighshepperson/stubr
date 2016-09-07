defmodule Stubr do
  @name_generator Application.get_env(:stubr, :name_generator)

  def stub(module, [function]) do
    create_stub(module, function)
  end

  defp create_stub(module, {name, args, impl}) do
    unique_name = @name_generator.generate()

    content = quote do
      def unquote(:"#{name}")(unquote_splicing(args)), do: unquote(impl)
    end

    {_, stub, _, _} = Module.create(:"Elixir.#{unique_name}", content, Macro.Env.location(__ENV__))

    stub
  end

end
