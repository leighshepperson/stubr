# Stubr

![Build Status](https://travis-ci.org/leighshepperson/stubr.svg?branch=master)

In functional languages you should write pure functions. However, sometimes we need functions to call external API’s that affect the state of the system. So these functions are impure. In non-functional languages you create mocks to test expectations. For example, you might create a mock of a repository and the test checks it calls the save function. You are testing a side effect. This is something you should avoid in functional languages.

Instead of mocks we should use stubs. Mocking frameworks tend to treat them as interchangeable and this makes it hard to tell them apart. So it is good to have a simple definition. [Quoting](http://martinfowler.com/articles/mocksArentStubs.html) Martin Fowler:

* Stubs provide canned answers to calls made during the test, usually not responding at all to anything outside what's programmed in for the test. Stubs may also record information about calls, such as an email gateway stub that remembers the messages it 'sent', or maybe only how many messages it 'sent'.
* Mocks are objects pre-programmed with expectations which form a specification of the calls they are expected to receive.

So what does Stubr provide:

* Stubr is not a mock framework
* Stubr is not a macro
* Stubr provides canned answers to calls made during a test
* Stubr makes it easy to create stubs
* Stubr makes sure the module you stub HAS the function you want to stub
* Stubr stubs as many functions and patterns as you want
* Stubr works without an explicit module. You set it up how you want
* Stubr lets you do asynchronous tests
* Stubr won't redefine your modules!
* Stubr has ZERO dependencies

## Example - Adapter for JSON PlaceHolder API

This is a simple JSONPlaceHolderAdapter built using TDD:

```elixir
defmodule Post do
  defstruct [:title, :body, :userId, :id]
end

defmodule JSONPlaceHolderAdapter do
  @posts_url "http://jsonplaceholder.typicode.com/posts"

  def get_post(id, http_client \\ HTTPoison) do
    "#{@posts_url}/#{id}"
    |> http_client.get
    |> handle_response
  end

  defp handle_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    post = body
    |> Poison.decode!(as: %Post{})
    {:ok, post}
  end

  defp handle_response({:ok, _}) do
    {:error, "Bad request"}
  end

  defp handle_response({:error, _}) do
    {:error, "Something went wrong"}
  end
end

```

Note the injected `http_client` argument of `JSONPlaceHolderAdapter.get_post/2` defaults to `HTTPoison`. This is so we can create a stub using Stubr.

Stubr is good for using test data to define stubs. It lets you iterate through test data to create the function representations. For example, if the stub returns a unique string A for userId 1 and a unique string B for userId 2 and something else parses those strings to return X and Y, then you can only expect to get X if and only if the user with userId 1 went through and Y if and only if the user with userId 2 went through.

You can see how this works in the following example:

```elixir

@post_url "http://jsonplaceholder.typicode.com/posts"

@good_test_data [
  %{
    id: 1,
    post_url: "#{@post_url}/1",
    expected: %Post{title: "A title", body: "Some body", userId: 2, id: 1},
    canned_body: "{\"userId\": 2,\"id\": 1,\"title\": \"A title\",\"body\": \"Some body\"}"
  },
  %{
    id: 2,
    post_url: "#{@post_url}/2",
    expected: %Post{title: "Another title", body: "Some other body", userId: 3, id: 2},
    canned_body: "{\"userId\": 3,\"id\": 2,\"title\": \"Another title\",\"body\": \"Some other body\"}"
  }
]

test "If the call to get a post is successful, then a return post struct with id, userId, body and title" do

  # Build the function definitions using the test data.
  # Alternatively, you could store the anonymous functions
  # with the test data to reduce the amount boilerplate code.

  functions = @good_test_data
  |> Enum.map fn %{post_url: post_url, canned_body: canned_body} ->

      # Note, the pin operator ^ guarantees it returns the correct response for a particular input

      {:get, fn(^post_url) -> {:ok, %HTTPoison.Response{body: canned_body, status_code: 200}} end}
    end

  http_client_stub = Stubr.stub!(functions, module: HTTPoison)

  for %{id: id, expected: expected} <- @good_test_data do
    assert JSONPlaceHolderAdapter.get_post(id, http_client_stub) == {:ok, expected}
  end
end

```

The remaining tests are set up the same way:

```elixir
@bad_test_data [
  %{id: 1, post_url: "#{@post_url}/1", status_code: 400},
  %{id: 2, post_url: "#{@post_url}/2", status_code: 500},
  %{id: 3, post_url: "#{@post_url}/3", status_code: 503}
]

test "If the response returns an invalid status code, then return error and a message" do
  functions = @bad_test_data
  |> Enum.map fn %{status_code: status_code, post_url: post_url} ->
      {:get, fn(^post_url) -> {:ok, %HTTPoison.Response{status_code: status_code}} end}
    end

  http_client_stub = Stubr.stub!(functions, module: HTTPoison)

  for %{id: id} <- @bad_test_data do
    assert JSONPlaceHolderAdapter.get_post(id, http_client_stub) == {:error, "Bad request"}
  end
end

test "If attempt to get data was unsuccessful, then return error and a message" do
  bad_response = {:get, fn(_) -> {:error, %HTTPoison.Error{}} end}

  http_client_stub = Stubr.stub!([bad_response], module: HTTPoison)

  assert JSONPlaceHolderAdapter.get_post(2, http_client_stub) == {:error, "Something went wrong"}
end

```

## Example - Creating Complex Stubs

Stubr can create stubs with functions of different arity, argument patterns and names:

```elixir
stubbed = Stubr.stub!([
  {:gravitational_acceleration, fn(:earth) -> 9.8 end},
  {:gravitational_acceleration, fn(:mars) -> 3.7 end},
  {:gravitational_acceleration, fn(:earth, :amsterdam) -> 9.813 end},
  {:gravitational_acceleration, fn(:earth, :havana) -> 9.788  end},
  {:gravitational_attraction, fn(m1, m2, r) -> 6.674e-11 * (m1 * m2) / (r * r) end}
])

assert stubbed.gravitational_acceleration(:earth) == 9.8
assert stubbed.gravitational_acceleration(:mars) == 3.7
assert stubbed.gravitational_acceleration(:earth, :amsterdam) == 9.813
assert stubbed.gravitational_acceleration(:earth, :havana) == 9.788
assert stubbed.gravitational_attraction(5.97e24, 1.99e30, 1.5e11) == 3.523960986666667e22
```

## Example - Auto-Stub

You can auto-stub modules by setting the `auto_stub` option to true. In this case, if you have not provided a function to stub, it will defer to the original implementation:

```elixir
stubbed = Stubr.stub!([
  {:ceil, fn 0.8 -> :stubbed_return end},
  {:parse, fn _ -> :stubbed_return end},
  {:round, fn(_, 1) -> :stubbed_return end},
  {:round, fn(1, 2) -> :stubbed_return end}
], module: Float, auto_stub: true)

assert stubbed.ceil(0.8) == :stubbed_return
assert stubbed.parse("0.3") == :stubbed_return
assert stubbed.round(8, 1) == :stubbed_return
assert stubbed.round(1, 2) == :stubbed_return
assert stubbed.round(1.2) == 1
assert stubbed.round(1.324, 2) == 1.32
assert stubbed.ceil(1.2) == 2
assert stubbed.ceil(1.2345, 2) == 1.24
assert stubbed.to_string(2.3) == "2.3"
```

## Example - Call Information

Stubr records information about function calls. In particular, the inputs and outputs of a function are recorded in the order that the function is called.

Each stubbed module has a function called `__stubr__` and this is used to get information about the stub.

For example, to get information about a particular function call, you can call the `__stubr__` function like so:

```elixir
stubbed = Stubr.stub!([
  {:ceil, fn 0.8 -> :stubbed_return end},
  {:parse, fn _ -> :stubbed_return end},
  {:round, fn(_, 1) -> :stubbed_return end},
  {:round, fn(1, 2) -> :stubbed_return end}
], module: Float, auto_stub: true, call_info: true)

stubbed.ceil(0.8)
stubbed.parse("0.3")
stubbed.round(8, 1)
stubbed.round(1, 2)
stubbed.round(1.2)
stubbed.round(1.324, 2)
stubbed.ceil(1.2)
stubbed.ceil(1.2345, 2)
stubbed.to_string(2.3)

assert stubbed.__stubr__(call_info: :ceil) == [
  %{input: [0.8], output: :stubbed_return},
  %{input: [1.2], output: 2.0},
  %{input: [1.2345, 2], output: 1.24}
]

assert stubbed.__stubr__(call_info: :parse) == [
  %{input: ["0.3"], output: :stubbed_return}
]

assert stubbed.__stubr__(call_info: :round) == [
  %{input: [8, 1], output: :stubbed_return},
  %{input: [1, 2], output: :stubbed_return},
  %{input: [1.2], output: 1.0},
  %{input: [1.324, 2], output: 1.32}
]

assert stubbed.__stubr__(call_info: :to_string) == [
  %{input: [2.3], output: "2.3"}
]
```

## Example - Behaviours

In [http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/) José Valim writes about finding "proper contracts and proper boundaries between the components" in your system. This is something Stubr can help you with to accomplish a "behaviour first" version of TDD.

For example, let's say you want to call an internal API and you decide to use an adapter to wrap it up. However, you haven't built the adapter yet, so you stub it out as an injected dependency without worrying about the implementation details.

So we might have something like this:

```
adapter_stub = Stubr.stub([
  {:get, fn("url") -> {:ok, "result"} end},
  {:put, fn("url", "data") -> {:ok} end}
])

# calls the get and put functions on the adapter stub
foo(adapter_stub)
```

Immediately, this suggests that the adapter needs a behaviour that looks something like this:

```
defmodule AdapterBehaviour do
  @callback get(url :: String.t) :: {:ok, String.t}
  @callback put(url :: String.t, data :: String.t) :: {:ok}
end
```

So we can "clip" this on to the stub using the behaviour option:

```
adapter_stub = Stubr.stub([
  {:get, fn("url") -> {:ok, "result"} end},
  {:put, fn("url", "data") -> {:ok} end}
], behaviour: AdapterBehaviour)
```

If the generated stub does not implement the behaviour, then it throws the usual compiler warning.

After we've completed all our tests, we can now implement the adapter and ensure it implements the `AdapterBehaviour`:

```
defmodule Adapter do
  @behaviour AdapterBehaviour

  def get(url), do: #call the internal API
  def put(url, data), do: #call the internal API
end
```

The good thing about this is: 

If you change the `Adapter`, then you should change the `AdapterBehaviour`. Since this will cause a compile time warning for the stub, it will encourage you to fix it, making your stubs and unit tests much less brittle.

## Links

How stubs can be used in TDD for functional languages: [https://www.infoq.com/presentations/mock-fsharp-tdd](https://www.infoq.com/presentations/mock-fsharp-tdd)

Mark Seemann's [blog post](http://blog.ploeh.dk/2013/10/23/mocks-for-commands-stubs-for-queries/) talks about the difference between Mocks and Stubs in the context of commands and queries.

## Roadmap

* <del>Metadata. Record information about calls</del>
* Behaviour aware stubs
* <del>Auto-stub modules: Defer to the original functionality</del>

## Installation

Stubr is [available in Hex](https://hex.pm/packages/stubr), the package can be installed as:

  1. Add `stubr` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:stubr, "~> 1.2.0"}]
    end
    ```

  2. Ensure `stubr` is started before your application:

    ```elixir
    def application do
      [applications: [:stubr]]
    end
    ```
