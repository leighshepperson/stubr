defmodule Stubr do
  @moduledoc """
  In functional languages you should write pure functions. However, sometimes we
  need functions to call external API’s. But these effect the state of the
  system. So these functions are impure. In non-functional languages you create
  mocks to test expectations. For example, you might create a mock of a
  repository. And the test checks it calls the update function. You are testing
  a side effect. This is something you should avoid in functional languages.

  Instead of mocks we should use stubs. Mocking frameworks tend to treat them
  as interchangeable. This makes it hard to tell them apart. So it is good
  to have a simple definition. [Quoting](http://martinfowler.com/articles/mocksArentStubs.html) Martin Fowler:

  * Stubs provide canned answers to calls made during the test, usually not
   responding at all to anything outside what's programmed in for the test.
   Stubs may also record information about calls, such as an email gateway
   stub that remembers the messages it 'sent', or maybe only how many
   messages it 'sent'.
  * Mocks are objects pre-programmed with expectations which form a
   specification of the calls they are expected to receive.

  So what does Stubr provide:

  * Stubr is not a mock framework
  * Stubr is not a macro
  * Stubr provides canned answers to calls made during a test
  * Stubr makes it easy to create stubs
  * Stubr makes sure the module you stub HAS the function you want to stub
  * Stubr works without an explicit module. You set it up how you want
  * Stubr won't redefine your modules!

  ## Example
  Say we want to test this module in different scenarios:

  ```
  defmodule WebGet do
    def get_body_and_upcase(url, http_client \\ HTTPoison) do
      {:ok, response} = http_client.get(url)
      response.body |> String.upcase
    end
  end
  ```

  Then we can use Stubr and test cases to get the http_client to provide different responses:

  ```
  test "It can upcase the body returned in the response" do
    test_cases = [
      %{url: "www.google.com", resp: {:ok, %HTTPoison.Response{body: "google"}}, expected: "GOOGLE"},
      %{url: "www.facebook.com", resp: {:ok, %HTTPoison.Response{body: "facebook"}}, expected: "FACEBOOK"},
      %{url: "www.microsoft.com", resp: {:ok, %HTTPoison.Response{body: "microsoft"}}, expected: "MICROSOFT"},
    ]

    functions_to_stub = test_cases
    |> Enum.map(fn(%{url: url, resp: resp}) -> {:get, fn(^url) -> resp end} end)

    # You don't even need to provide HTTPoison - it just checks to see if HTTPoison.get/1 actually exists
    stubbed_http_client = Stubr.stub(HTTPoison, functions_to_stub)

    for %{expected: expected, url: url} <- test_cases do
      assert WebGet.get_body_and_upcase(url, stubbed_http_client) == expected
    end
  end
  ```

  How cool was that!
  """

  @doc ~S"""
  Creates a stub using a module as a safety net. Define the functions how you like,
  just make sure they are defined in the module you want to stub. Otherwise it will
  throw an `UndefinedFunctionError`. Useful if you are stubbing modules from libraries
  that could depreciate your favorite function.

  ## Examples
      iex> defmodule Foo, do: def test(1), do: :ok
      iex> Stubr.stub(Foo, [{:test, fn(_) -> :good_bye end}]).test(1)
      :good_bye

      iex> defmodule Bar, do: def test(x, y, z), do: x + y + z
      iex> Stubr.stub(Bar, [{:test, fn(1, 2, x) -> 1 + 2 * x end}]).test(1, 2, 9)
      19
  """
  @spec stub(module(), list({atom(), (... -> any())})) :: module() | Error
  def stub(module, function_reps) do
    {:ok} = is_defined!(module, function_reps)
    stub(function_reps)
  end

  @doc ~S"""
  Creates a stub. Define the functions how you like. Useful if you are building
  an application using TDD. Stub it out first, then create the implementation when
  you know its behaviour.

  ## Examples
      iex> Stubr.stub([{:foo, fn(1, 2, 3) -> :bar end}]).foo(1, 2, 3)
      :bar

      iex> Stubr.stub([{:bar, fn(x, y, z, u) -> x*y*z + u end}]).bar(1, 2, 3, 4)
      10
  """
  @spec stub(list({atom(), (... -> any())})) :: module() | Error
  def stub(function_reps) do
    {:ok, pid} = StubrAgent.start_link

    function_reps
    |> Enum.each(&StubrAgent.register_function(pid, &1))

    function_reps
    |> create_body(pid)
    |> create_module
  end

  defp is_defined!(module, function_reps) do
    module_function_set = MapSet.new(module.module_info(:functions))

    for {name, impl} <- function_reps do
      if !MapSet.member?(module_function_set, {name, :erlang.fun_info(impl)[:arity]}) do
        raise UndefinedFunctionError
      end
    end

    {:ok}
  end

  defp create_body(function_reps, pid) do
    function_args = function_reps |> get_args

    quote bind_quoted: [function_args: Macro.escape(function_args), pid: pid] do
      for {name, args} <- function_args do
        def unquote(name)(unquote_splicing(args)) do
          StubrAgent.eval_function(unquote(pid), {unquote(name), binding()})
        end
      end
    end
  end

  defp create_module(body) do
    random_string = (for _ <- 1..32, do: :rand.uniform(26) + 96)

    module_name = random_string
    |> to_string
    |> String.capitalize

    {_, module, _, _} = Module.create(:"Stubr.#{module_name}", body, Macro.Env.location(__ENV__))

    module
  end

  defp get_args({name, function}),
    do: {name, create_args(function)}
  defp get_args(functions_reps),
    do: functions_reps |> Enum.map(&get_args(&1))

  defp create_args(function) do
    arity = (function |> :erlang.fun_info)[:arity]
    Enum.map(1..arity, &(Macro.var (:"arg#{&1}"), nil))
  end

end
