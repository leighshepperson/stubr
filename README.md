# Stubr

![Build Status](https://travis-ci.org/leighshepperson/stubr.svg?branch=master)

In functional languages you should write pure functions. However, sometimes we need functions to call external API’s. But these affect the state of the system. So these functions are impure. In non-functional languages you create mocks to test expectations. For example, you might create a mock of a repository. And the test checks it calls the update function. You are testing a side effect. This is something you should avoid in functional languages. 

Instead of mocks we should use stubs. Mocking frameworks tend to treat them as interchangeable. This makes it hard to tell them apart. So it is good to have a simple definition. [Quoting](http://martinfowler.com/articles/mocksArentStubs.html) Martin Fowler:

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

## Example
Say we want to test this module in different scenarios:

```elixir
defmodule WebGet do
  def get_body_and_upcase(url, http_client \\ HTTPoison) do
    {:ok, response} = http_client.get(url)
    response.body |> String.upcase
  end
end
```

Then we can use Stubr and test cases to get the http_client to provide different responses:

```elixir
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

## Links

To see how stubs can be used in TDD, see [https://www.infoq.com/presentations/mock-fsharp-tdd](https://www.infoq.com/presentations/mock-fsharp-tdd)

## Installation

Stubr is [available in Hex](https://hex.pm/packages/stubr), the package can be installed as:

  1. Add `stubr` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:stubr, "~> 1.0.1"}]
    end
    ```

  2. Ensure `stubr` is started before your application:

    ```elixir
    def application do
      [applications: [:stubr]]
    end
    ```

