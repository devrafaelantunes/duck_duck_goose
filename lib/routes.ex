defmodule DuckDuckGoose.Routes do
  @moduledoc """
  Manages the routing for the DuckDuckGoose application.

  This module defines routes for the web service and provides functionalities to dynamically
  recompile these routes at runtime, enabling changes to be applied without restarting the server.
  """

  alias DuckDuckGoose.Handler

  @doc """
  Defines the list of routes for the application.

  Each route is a tuple consisting of the path, handler module, and any additional options
  that the handler might require.

  ## Returns
  - A list of routes where each route is defined as a tuple.

  ## Examples

      iex> DuckDuckGoose.Routes.routes()
      [{"/status", DuckDuckGoose.Handler, %{endpoint: :status}}]
  """
  @spec routes() :: list()
  def routes do
    [
      {"/status", Handler, %{endpoint: :status}}
    ]
  end

  @doc """
  Recompiles the application's routes at runtime and stores the compiled routes in persistent term storage.

  This function uses `:cowboy_router.compile/1` to compile the routes and then stores the compiled
  dispatch table in a persistent term for fast access. This allows for changes to the routing table
  without requiring a restart of the application.

  ## Examples

      iex> DuckDuckGoose.Routes.recompile()
      :ok

  ## Returns
  - `:ok` on successful recompilation and storage of the dispatch table.
  """
  @spec recompile() :: :ok
  def recompile do
    dispatch = :cowboy_router.compile([{:_, routes()}])
    :persistent_term.put(:duck_duck_goose_dispatch, dispatch)
    :ok
  end
end
