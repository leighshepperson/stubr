defmodule Stubr do
  @moduledoc ~S"""
  Provides stubs for Elixir.

  Module stubs can be created using `create!/1` and `create!/2`.
  The input to this function is a keyword list of function names
  (expressed as atoms) and their implementations (expressed as
  anonymous functions):

      [function_name: (...) -> any()]

  Additionally, takes an optional keyword list to configure the stub.

  ## Options

  The options available to `create!/2` are:

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
    Stubr.Stub.create!(functions, opts)
  end

  @doc ~S"""
  Creates a spy of the provided module. All function calls
  are defered to the original module and call information
  is recorded.

  ## Examples

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(1.3)
      2.0
      iex> Stubr.call_info!(spy, :ceil)
      [%{input: [1.3], output: 2.0}]

  """
  def spy!(module) do
    Stubr.stub!([], module: module, call_info: true, auto_stub: true)
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
  Returns `true` if the anonymous function `fun` returns `true` when invoked
  against the arguments of at least one function call.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_function = [foo: fn(_) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_function, call_info: true)
      iex> stub.foo(%{bar: :ok, baz: :error})
      iex> stub |> Stubr.called_where?(:foo, fn [arg] -> Map.has_key?(arg, :bar) end)
      true
      iex> stub |> Stubr.called_where?(:foo, fn [arg] -> arg.baz == :ok end)
      false

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(1.9)
      iex> spy |> Stubr.called_where?(:ceil, fn [arg] -> arg == 1.9 end)
      true
      iex> spy |> Stubr.called_where?(:ceil, fn [arg] -> arg == 2.0 end)
      false

  """
  def called_where?(stub, function_name, fun) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.any?(&fun.(&1.input))
  end

  @doc ~S"""
  Returns true if the stubbed function is called at least once with a given argument.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_function = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_function, call_info: true)
      iex> stub.foo(:bar, :baz)
      iex> stub |> Stubr.called_with?(:foo, [:bar, :baz])
      true
      iex> stub |> Stubr.called_with?(:foo, [:qux])
      false

      iex> spy = Stubr.spy!(Float)
      iex> spy.floor(7.9)
      iex> spy |> Stubr.called_with?(:floor, [7.9])
      true
      iex> spy |> Stubr.called_with?(:floor, [8])
      false

  """
  def called_with?(stub, function_name, arguments) do
    stub
    |> called_where?(function_name, &(&1 == arguments))
  end

  @doc ~S"""
  Returns number of times the function was called.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz)
      iex> stub.foo(:baz, :qux)
      iex> stub |> Stubr.call_count(:foo)
      3

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy |> Stubr.call_count(:ceil)
      2

  """
  def call_count(stub, function_name) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.count
  end

  @doc ~S"""
  Returns `true` if the function was called once.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called_once?(:foo)
      true

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy |> Stubr.called_once?(:ceil)
      false

  """
  def called_once?(stub, function_name),
    do: called_many?(stub, function_name, 1)

  @doc ~S"""
  Returns `true` if the function was called twice.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called_twice?(:foo)
      false

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy |> Stubr.called_twice?(:ceil)
      true

  """
  def called_twice?(stub, function_name),
    do: called_many?(stub, function_name, 2)

  @doc ~S"""
  Returns `true` if the function was called three times.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called_thrice?(:foo)
      false

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy |> Stubr.called_thrice?(:ceil)
      true

  """
  def called_thrice?(stub, function_name),
    do: called_many?(stub, function_name, 3)

  @doc ~S"""
  Returns `true` if the function was called n-many times.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called_many?(:foo, 2)
      false

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy |> Stubr.called_many?(:ceil, 3)
      true

  """
  def called_many?(stub, function_name, n),
    do: stub |> call_count(function_name) == n

  @doc ~S"""
  Returns the first call passed to the function.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.first_call(:foo)
      [:baz]

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy |> Stubr.first_call(:ceil)
      [0.2]

  """
  def first_call(stub, function_name),
    do: get_call(stub, function_name, 1)

  @doc ~S"""
  Returns the second call passed to the function.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:bar, :baz)
      iex> stub.foo(:bar, :qux)
      iex> stub |> Stubr.second_call(:foo)
      [:bar, :qux]

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy |> Stubr.second_call(:ceil)
      [1.3]

  """
  def second_call(stub, function_name),
    do: get_call(stub, function_name, 2)

  @doc ~S"""
  Returns the third call passed to the function.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(1, 2)
      iex> stub.foo(3, 4)
      iex> stub.foo(5, 6)
      iex> stub |> Stubr.third_call(:foo)
      [5, 6]

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy |> Stubr.third_call(:ceil)
      [2.4]

  """
  def third_call(stub, function_name),
    do: get_call(stub, function_name, 3)

  @doc ~S"""
  Returns the last call passed to the function.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(1, 2)
      iex> stub.foo(3, 4)
      iex> stub |> Stubr.last_call(:foo)
      [3, 4]

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy.ceil(4.4)
      iex> spy |> Stubr.last_call(:ceil)
      [4.4]

  """
  def last_call(stub, function_name) do
    number_of_calls = stub
    |> Stubr.call_info!(function_name)
    |> Enum.count

    stub
    |> get_call(function_name, number_of_calls)
  end

  @doc ~S"""
  Returns the nth call passed to the function.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(1, 2)
      iex> stub.foo(3, 4)
      iex> stub |> Stubr.get_call(:foo, 2)
      [3, 4]

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy.ceil(4.4)
      iex> spy |> Stubr.get_call(:ceil, 3)
      [2.4]

  """
  def get_call(stub, function_name, n) do
    %{input: input} = stub
    |> Stubr.call_info!(function_name)
    |> Enum.at(n - 1)

    input
  end

  @doc ~S"""
  Returns `true` if function is called with exact inputs.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(1, 2)
      iex> stub.foo(3, 4)
      iex> stub |> Stubr.called_with_exactly?(:foo, [[1, 2], [3, 4]])
      true

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy.ceil(4.4)
      iex> spy |> Stubr.called_with_exactly?(:ceil, [[0.2], [2.3]])
      false

  """
  def called_with_exactly?(stub, function_name, args) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.reduce([], fn i, acc -> [i.input | acc] end)
    |> Enum.reverse
    == args
  end

  @doc ~S"""
  Returns `true` if at least one of the function calls returns the
  specified value.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_, _) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(1, 2)
      iex> stub.foo(3, 4)
      iex> stub |> Stubr.returned?(:foo, :ok)
      true

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(2.4)
      iex> spy.ceil(4.4)
      iex> spy |> Stubr.returned?(:ceil, 3.0)
      true

  """
  def returned?(stub, function_name, output) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.any?(fn i -> i.output == output end)
  end

  @doc ~S"""
  Returns the number of times the function was called with a given arguement.

  If you are using a stub, then the `call_info` option must be set to `true`.

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

      iex> spy = Stubr.spy!(Float)
      iex> spy.ceil(0.2)
      iex> spy.ceil(1.3)
      iex> spy.ceil(1.3)
      iex> spy.ceil(4.4)
      iex> spy |> Stubr.call_count(:ceil, [1.3])
      2

  """
  def call_count(stub, function_name, arguments) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.count(fn(%{input: input}) -> input == arguments end)
  end

  @doc ~S"""
  Returns `true` if the function was called.

  If you are using a stub, then the `call_info` option must be set to `true`.

  ## Examples

      iex> stubbed_functions = [foo: fn(_) -> :ok end, bar: fn(_) -> :ok end]
      iex> stub = Stubr.stub!(stubbed_functions, call_info: true)
      iex> stub.foo(:baz)
      iex> stub |> Stubr.called?(:foo)
      true
      iex> stub |> Stubr.called?(:bar)
      false

      iex> stub = Stubr.spy!(Float)
      iex> stub.ceil(2.3)
      iex> stub |> Stubr.called?(:ceil)
      true
      iex> stub |> Stubr.called?(:floor)
      false

  """
  def called?(stub, function_name) do
    stub
    |> Stubr.call_info!(function_name)
    |> Enum.any?
  end

end
