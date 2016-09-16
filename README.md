# Stubr

In functional languages you should write pure functions. However, sometimes we need functions to call external API’s. But these effect the state of the system. So these functions are impure. In non-functional languages you create mocks to test expectations. For example, you might create a mock of a repository. And the test checks it calls the update function. You are testing a side effect. This is something you should avoid in functional languages. 

Instead of mocks we should use stubs. Mocking frameworks tend to treat them as interchangeable. This makes it hard to tell them apart. So it is good to have a simple definition. [Quoting](http://martinfowler.com/articles/mocksArentStubs.html) Martin Fowler:

* Stubs provide canned answers to calls made during the test, usually not responding at all to anything outside what's programmed in for the test. Stubs may also record information about calls, such as an email gateway stub that remembers the messages it 'sent', or maybe only how many messages it 'sent'.
* Mocks are objects pre-programmed with expectations which form a specification of the calls they are expected to receive.

So what does Stubr provide:
* Stubr is not a mock framework
* Stubr is not a macro
* Stubr provides canned answers to calls made during a test
* Stubr makes it easy to create stubs
* Stubr makes sure the module you stub HAS the function you want to stub
* Stubr works without an explicit module. You set it up how you want

## Example
The expression

```
stubbed = Stubr.stub(HTTPoison, [
  {:get, fn(url) -> {:ok, %HTTPoison.Response{status_code: 500}}}
])
```
  
creates a new module that returns a `HTTPoison.Response` struct when it invokes the `XXX.get/1` function. You pass in `stubbed` as a parameter to functions that need to use `HTTPoison`. 

For example, given this module:

```
defmodule Foo do

  def bar(http_client \\ HTTPoison) do
     http_client.get("www.google.com")
  end

end
```

pass it the stubbed `HTTPoison` like this:

```
iex> Foo.bar(stubbed)
{:ok, %HTTPoison.Response{status_code: 500}}}
```

To learn more about this approach, see [https://www.infoq.com/presentations/mock-fsharp-tdd](https://www.infoq.com/presentations/mock-fsharp-tdd)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `stubr` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:stubr, "~> 0.1.0"}]
    end
    ```

  2. Ensure `stubr` is started before your application:

    ```elixir
    def application do
      [applications: [:stubr]]
    end
    ```

