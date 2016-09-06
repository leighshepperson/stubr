defmodule Stubr.Errors.ModuleExistsError do
  defexception message: "A module matching the name of the stub already exists"
end