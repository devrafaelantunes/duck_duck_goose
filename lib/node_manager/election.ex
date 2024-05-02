defmodule DuckDuckGoose.NodeManager.Election do
  @moduledoc """
  Manages the election process for leader selection among nodes.

  This module handles scheduling and conducting leader elections, ensuring that only
  one node acts as leader at any given time by coordinating with all nodes in the system.
  """

  require Logger
  alias DuckDuckGoose.NodeManager.{Heartbeat, Broadcast}
  alias DuckDuckGoose.RpcWrapper

  @manager_registration DuckDuckGoose.NodeManager
  @manager_api DuckDuckGoose.NodeManager.API

  @doc """
  Schedules an election if the current leader is not responsive.

  ## Parameters
  - `state`: The current state of the node containing the leader's information.

  ## Returns
  - `:ok` if the leader is still active.
  - Schedules an election otherwise.
  """
  @spec schedule(map()) :: :ok | no_return()
  def schedule(state) do
    # Generates the delay based on the min/max config
    delay = generate_delay(min_delay(), max_delay())

    # Checks if a leader was already elected
    if Node.ping(state.leader) == :pong do
      {:ok, :already_elected}
    else
      Logger.info("Scheduling leader election in #{delay} ms...")
      Process.send_after(self(), :elect_leader, delay)
    end
  end

  @doc """
  Conducts a leader election among nodes.

  This function attempts to elect a leader by requesting votes from other nodes.
  If a majority is achieved, the current node assumes the leader role and starts heartbeats.

  ## Parameters
  - `state`: The current state of the node.

  ## Returns
  - The updated state if elected as leader.
  - Calls `schedule/1` to retry otherwise.
  """
  @spec elect_leader(map()) :: map()
  def elect_leader(state) do
    Logger.info("Electing leader...")
    votes = request_votes()

    if majority_votes?(votes) do
      new_state = %{state | role: :goose, leader: Node.self()}
      # Broadcasts the new leader
      Broadcast.run(@manager_registration, :leader_update, new_state.leader)
      Heartbeat.schedule(new_state)
      new_state
    else
      schedule(state)
      state
    end
  end

  @doc """
  Determines if a majority of votes has been received.

  A majority is defined as more than half of the currently active nodes. This function
  counts the number of votes where the vote is `:granted` and checks if this count exceeds
  half of the total number of nodes in the cluster.

  ## Parameters
  - `votes`: A list of votes, where each vote can be `:granted` or `:no_response`.

  ## Returns
  - `true` if the number of `:granted` votes is more than half of the total nodes.
  - `false` otherwise.

  ## Examples

      iex> DuckDuckGoose.NodeManager.Election.majority_votes?([:granted, :granted, :no_response])
      true
  """
  @spec majority_votes?([atom()]) :: boolean()
  def majority_votes?(votes) do
    num_votes = Enum.count(votes)
    num_votes >= div(Enum.count(Node.list()), 2) + 1
  end

  @doc false
  defp request_votes() do
    Logger.info("Requesting votes from other nodes asynchronously...")
    # Requests the vote from other nodes only
    nodes = Node.list() |> Enum.reject(&(&1 == Node.self()))

    Task.async_stream(
      nodes,
      fn node -> RpcWrapper.call(node, @manager_api, :vote_request, [Node.self()]) end,
      timeout: 5000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, response} -> response
      _ -> :no_response
    end)
    |> Enum.filter(fn vote -> vote == :granted end)
  end

  @doc false
  defp generate_delay(min, max), do: :rand.uniform(max - min + 1) + min - 1
  @doc false
  defp min_delay(), do: Application.get_env(:duck_duck_goose, :min_election_delay, 500)
  @doc false
  defp max_delay(), do: Application.get_env(:duck_duck_goose, :max_election_delay, 10000)
end
