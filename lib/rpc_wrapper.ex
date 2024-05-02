defmodule DuckDuckGoose.RpcWrapper do
  @moduledoc """
  Provides a wrapper around the Erlang `:rpc` module functions.

  This wrapper is specifically designed to facilitate the mocking of `:rpc` calls in tests,
  allowing the `:rpc` module to be replaced by Mimic during test runs. This approach
  helps isolate tests from actual RPC execution, enabling more controlled and deterministic
  test environments.
  """

  @doc """
  Executes a remote procedure call on a given node.

  This function is a direct interface to `:rpc.call` which performs the actual RPC.

  ## Parameters

  - `node`: The node on which the function should be called.
  - `module`: The module that contains the function to be called.
  - `function`: The function to call.
  - `args`: A list of arguments to pass to the function.

  ## Returns

  - The result of the remote procedure call.
  """
  @spec call(node(), module(), atom(), list()) :: any()
  def call(node, module, function, args) do
    :rpc.call(node, module, function, args)
  end
end
