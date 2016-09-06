defmodule Stubr do
  alias Stubr.Errors.ModuleExistsError
  @name_generator Application.get_env(:stubr, :name_generator)

  def stub(module, [function]) do
    create_stub(module, function)
  end

  defp create_stub(module, {name, args, impl}) do
    unique_name = @name_generator.generate()

    content = quote do
      def unquote(:"#{name}")(unquote_splicing(args)) do
        unquote(impl.(1,2,3))
      end
    end

    {_, stub, _, _} = Module.create(:"Elixir.#{unique_name}", content, Macro.Env.location(__ENV__))

    stub
  end

  defp check_module_loaded(module) do
    case Code.ensure_loaded(module) do
      {:error, _} -> {:ok}
      _ -> raise ModuleExistsError
    end
  end

end
