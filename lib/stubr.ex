defmodule Stubr do
  @moduledoc ~S"""
  Provides module stubs for Elixir.
  Module stubs can be created using `stub!/1` and `stub!/2`.
  The input to this function is a keyword list of function names
  (expressed as atoms) and their implementations (expressed as
  anonymous functions):

      [function_name: (...) -> any()]

  Additionally, takes an optional keyword list to configure the stub.

  ## Options

  The options available to `stub!/2` are:

    * `:module` - when set, if the module does not contain a function
      defined in the keyword list, then raises an `UndefinedFunctionError`

    * `:auto_stub` - when true and a module has been set, if there
      is not a matching function, then defers to the module function
      (defaults to `false`)

    * `behaviour` - when set, raises a warning if the stub does not
      implement the behaviour

    * `call_info` - when set, if a function is called, records the input
      and the output to the function. Accessed by calling
      `__stubr__(:call_info: :function_name)`
      (defaults to `false`)

  """

  @auto_stub Application.get_env(:stubr, :auto_stub) || false
  @call_info Application.get_env(:stubr, :call_info) || false

  @defaults [auto_stub: @auto_stub, module: nil, behaviour: nil, call_info: @call_info]

  @doc ~S"""
  Recieves a keyword list of function names and anonymous functions
  where all calls by the stub to a function in this list are deferred
  to the invocation of the anonymous function.

  ## Options

    * `:module` - when set, if the module does not contain a function
      defined in the keyword list, then raises an `UndefinedFunctionError`

    * `:auto_stub` - when true and a module has been set, if there
      is not a matching function, then defers to the module.
      (defaults to `false`)

    * `behaviour` - when set, raises a warning if the stub does not
      implement the behaviour

    * `call_info` - when set, if a function is called, records the input
      and the output to the function. Accessed by calling
      `__stubr__(:call_info: :function_name)`
      (defaults to `false`)

  ## Examples

      iex> uniform_stub = [uniform: fn(_) -> 3 end]
      iex> rand_stub = Stubr.stub!(uniform_stub, module: :rand)
      iex> rand_stub.uniform(2)
      3
      iex> rand_stub.uniform(4)
      3

  """
  def stub!(functions, opts \\ []) do
    opts = @defaults
    |> Keyword.merge(opts)
    |> Enum.into(%{})

    {:ok} = can_stub!(functions, opts)

    {:ok, pid} = add_functions_to_server(functions)

    do_stub(pid, functions, opts)
  end

  @doc ~S"""
  Returns the call info of a stubbed module.

  ## Examples

      iex> uniform_stub = [uniform: fn(_) -> 3 end]
      iex> rand_stub = Stubr.stub!(uniform_stub, module: :rand, call_info: true)
      iex> rand_stub.uniform(2)
      3
      iex> Stubr.call_info!(rand_stub, :uniform)
      [%{input: [2], output: 3}]

  """
  def call_info!(stub, function_name) do
    case stub.__stubr__(call_info: function_name) do
      nil -> []
      result -> result
    end
  end

  @doc ~S"""
  Returns true if the invocation of the anonymous function returns
  true when applied to the arguments of at least one function call. The
  `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_function = [foo: fn(_) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_function, call_info: true)
      iex> stub.foo(%{bar: :ok, baz: :error})
      iex> stub |> Stubr.called_match?(:foo, fn [arg] -> Map.has_key?(arg, :bar) end)
      true
      iex> stub |> Stubr.called_match?(:foo, fn [arg] -> arg.baz == :ok end)
      false

  """
  def called_match?(stub, function_name, match_function) when is_function(match_function) do
    stub
    |> call_info!(function_name)
    |> Enum.any?(fn(%{input: input}) -> do_apply_called_with(match_function, input) end)
  end

  @doc ~S"""
  Returns true if the stubbed function is called with a particular argument. The
  `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_function = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_function, call_info: true)
      iex> stub.foo(:bar, :baz)
      iex> stub |> Stubr.called_with?(:foo, [:bar, :baz])
      true
      iex> stub |> Stubr.called_with?(:foo, [:qux])
      false

  """
  def called_with?(stub, function_name, arguments) do
    stub
    |> call_info!(function_name)
    |> Enum.any?(fn(%{input: input}) -> input == arguments end)
  end

  @doc ~S"""
  Returns number of times the function was called. The
  `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz, :qux)
      iex> stub |> Stubr.call_count(:foo)
      3

  """
  def call_count(stub, function_name) do
    stub
    |> call_info!(function_name)
    |> Enum.count
  end

  @doc ~S"""
  Returns number of times the function was called for a particular
  arguement. The `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz, :qux)
      iex> stub |> Stubr.call_count(:foo, [:baz])
      2
      iex> stub |> Stubr.call_count(:foo, [:baz, :qux])
      1

  """
  def call_count(stub, function_name, arguments) do
    stub
    |> call_info!(function_name)
    |> Enum.count(fn(%{input: input}) -> input == arguments end)
  end

  @doc ~S"""
  Returns true if the stubbed function was called. The
  `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, bar: fn(_) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called?(:foo)
      true
      iex> stub |> Stubr.called?(:bar)
      false

  """
  def called?(stub, function_name) do
    stub
    |> call_info!(function_name)
    |> Enum.any?
  end

  defp do_apply_called_with(function, input) do
    try do
      function.(input)
    rescue
      _ -> false
    end
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
          raise StubrError, message: "The call_info option must be set and equal to true"
        end
      end

      for {function_name, args_for_function} <- args_for_functions do
        def unquote(function_name)(unquote_splicing(args_for_function)) do
          variable_values = for {_, variable_value} <- binding, do: variable_value

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
