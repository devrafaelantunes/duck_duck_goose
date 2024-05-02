defmodule DuckDuckGoose.NodeManager.API do
  @moduledoc """
  Provides an API for interacting with the NodeManager GenServer, facilitating
  operations such as fetching the node's role, managing heartbeats, and handling
  voting requests.
  """

  @node_manager DuckDuckGoose.NodeManager

  require Logger

  @doc """
  Fetches the current role of the node from the NodeManager.

  Returns `:ok` on success.

  ## Examples

      iex> DuckDuckGoose.NodeManager.API.fetch_role()
      %{role: :goose || :duck, node: node}
  """
  @spec fetch_role() :: map()
  def fetch_role do
    GenServer.call(@node_manager, :get_role)
  end

  @doc """
  Sends a heartbeat signal to the NodeManager with the given leader node.

  Returns `:ok`.

  ## Examples

      iex> DuckDuckGoose.NodeManager.API.heartbeat(:leader_node)
      :ok
  """
  @spec heartbeat(atom()) :: :ok
  def heartbeat(leader) do
    GenServer.cast(@node_manager, {:heartbeat, leader})
    :ok
  end

  @doc """
  Cancels the heartbeat timer in the NodeManager.

  Returns `:ok`.

  ## Examples

      iex> DuckDuckGoose.NodeManager.API.cancel_heartbeat_timer()
      :ok
  """
  @spec cancel_heartbeat_timer() :: :ok
  def cancel_heartbeat_timer do
    GenServer.cast(@node_manager, :cancel_heartbeat_timer)
    :ok
  end

  @doc """
  Requests a vote from the NodeManager for the specified caller node.

  Logs the request and returns `:ok` on success.

  ## Examples

      iex> DuckDuckGoose.NodeManager.API.vote_request(:some_node)
      :granted || :rejected
  """
  @spec vote_request(atom()) :: atom()
  def vote_request(caller) do
    Logger.debug("Sending vote request from #{inspect(caller)}...")
    GenServer.call(@node_manager, {:vote_request, caller}, 40000)
  end
end
