# Stubr

![Build Status](https://travis-ci.org/leighshepperson/stubr.svg?branch=master)

Stubr is a set of functions helping people to create stubs and spies in Elixir.

## About

In Elixir, you should aim to write pure functions. However, sometimes you need to write functions that post to external API’s or functions that depend on the current time. Since these actions can lead to side effects, they can make it harder to unit test your system.

Stubr solves this problem by taking cues from [mocks and explicit contracts](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/). It provides a set of functions that help people create "mocks as nouns" and not "mocks as verbs":

```elixir
iex> stub = Stubr.stub!([foo: fn _ -> :ok end], call_info: true)
iex> stub.foo(1)
iex> stub |> Stubr.called_once?(:foo)
true

iex> spy = Stubr.spy!(Float)
iex> spy.ceil(1.5)
iex> spy |> Stubr.called_with?(:ceil, [1.5])
true
iex> spy |> Stubr.called_twice?(:ceil)
false
```

## Installation

Stubr is [available in Hex](https://hex.pm/packages/stubr), the package can be installed as:

Add `stubr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:stubr, "~> 1.4.0", only: :test}]
end
```


## Developer documentation

Stubr documentation is [available in hexdocs](https://hexdocs.pm/stubr/Stubr.html).

## Examples

### Random numbers

It is easy to use `Stubr.stub!` to set up a stub for the `uniform/1` function in the `:rand` module. Note, there is no need to explicitly set the module option, it is just used to make sure the `uniform/1` function exists in the `:rand` module.

```elixir
test "create a stub of the :rand.uniform/1 function" do
  rand_stub = Stubr.stub!([uniform: fn _ -> 1 end], module: :rand)

  assert rand_stub.uniform(1) == 1
  assert rand_stub.uniform(2) == 1
  assert rand_stub.uniform(3) == 1
  assert rand_stub.uniform(4) == 1
  assert rand_stub.uniform(5) == 1
  assert rand_stub.uniform(6) == 1
end
```

### Timex

As above, we can use `Stubr.stub!` to stub the `Timex.now/0` function in the `Timex` module. However, we also want the stub to defer to the original functionality of the `Timex.before?/2` function. To do this, we just set the `module` option to `Timex` and the `auto_stub` option to `true`.

```elixir
test "create a stub of Timex.now/0 and defer on all other functions" do
  fixed_time = Timex.to_datetime({2999, 12, 30})

  timex_stub = Stubr.stub!([now: fn -> fixed_time end], module: Timex, auto_stub: true)

  assert timex_stub.now == fixed_time
  assert timex_stub.before?(fixed_time, timex_stub.shift(fixed_time, days: 1))
end
```

### HTTPoison

In this example, we create stubs of the functions `get` and `post` in the `HTTPoison` module that return different values dependant on their inputs:

```elixir
setup_all do
  http_poison_stub = Stubr.stub!([
    get: fn("www.google.com") -> {:ok, %HTTPoison.Response{body: "search", status_code: 200}} end,
    get: fn("www.nasa.com") -> {:ok, %HTTPoison.Response{status_code: 401}} end,
    post: fn("www.nasa.com", _) -> {:error, %HTTPoison.Error{reason: :econnrefused}} end
  ], module: HTTPoison)

  [stub: http_poison_stub]
end

test "create a stub of HTTPoison.get/1", context do
  {:ok, google_response} = context[:stub].get("www.google.com")
  {:ok, nasa_response} = context[:stub].get("www.nasa.com")

  assert google_response.body == "search"
  assert google_response.status_code == 200
  assert nasa_response.status_code == 401
end

test "create a stub of HTTPoison.post/2", context do
  {:error, error} = context[:stub].post("www.nasa.com", "any content")

  assert error.reason == :econnrefused
end
```

## Links

Here is a good guide to TDD in functional languages using stubs: [https://www.infoq.com/presentations/mock-fsharp-tdd](https://www.infoq.com/presentations/mock-fsharp-tdd)

Mark Seemann's [blog post](http://blog.ploeh.dk/2013/10/23/mocks-for-commands-stubs-for-queries/) talks about the difference between Mocks and Stubs in the context of commands and queries.
