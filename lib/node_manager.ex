defmodule DuckDuckGoose.NodeManager do
  @moduledoc """
  Manages the node state and interactions within the DuckDuckGoose cluster.

  This GenServer handles node roles, leader elections, and node heartbeats, ensuring
  high availability and consistency across the cluster.
  """

  use GenServer
  require Logger

  alias DuckDuckGoose.NodeManager.{Heartbeat, Broadcast, Election}

  @duck :duck
  @goose :goose
  @max_attempts 5

  # Start and Init functions
  @doc """
  Starts the NodeManager GenServer.

  ## Examples

      iex> DuckDuckGoose.NodeManager.start_link([])
      {:ok, pid}
  """
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(_args) do
    Logger.info("Starting DuckDuckGoose.NodeManager GenServer...")

    GenServer.start_link(
      __MODULE__,
      %{role: @duck, leader: nil, heartbeat_timer: nil, attempts: 0},
      name: __MODULE__
    )
  end

  @doc """
  Initializes the GenServer with the initial state and starts node monitoring.

  ## Parameters
  - `state`: The initial state of the NodeManager.

  ## Returns
  - `{:ok, state}` on successful initialization.
  """
  @spec init(map()) :: {:ok, map()}
  def init(state) do
    # Starts the node monitoring
    :net_kernel.monitor_nodes(true)
    Logger.info("Initializing DuckDuckGoose.NodeManager GenServer...")
    Election.schedule(state)
    {:ok, state}
  end

  # Handle Call functions
  @doc """
  Handles synchronous call for getting the current node role.

  ## Parameters
  - `:get_role`: The request type.
  - `_from`: The caller's process information.
  - `state`: Current GenServer state.

  ## Returns
  - `{:reply, response, state}` where `response` is the current node role and node information.
  """
  @spec handle_call(:get_role, {pid(), term()}, map()) :: {:reply, map(), map()}
  def handle_call(:get_role, _from, state) do
    Logger.debug("Handling request to get role...")
    {:reply, %{role: state.role, node: Node.self()}, state}
  end

  @doc """
  Handles synchronous call for vote requests.

  Grants or rejects votes based on the current node's state and role.

  ## Parameters
  - `{:vote_request, caller}`: The request tuple containing the caller.
  - `_from`: The caller's process information.
  - `state`: Current GenServer state.

  ## Returns
  - `{:reply, :granted | :rejected, state}` depending on the voting outcome.
  """
  @spec handle_call({:vote_request, pid()}, {pid(), term()}, map()) :: {:reply, atom(), map()}
  def handle_call({:vote_request, caller}, _from, state) do
    Logger.debug("Handling vote request from #{inspect(caller)}...")

    case state.role do
      @duck when state.leader == nil or state.attempts > @max_attempts ->
        {:reply, :granted, %{state | leader: caller, attempts: 0}}

      _ ->
        {:reply, :rejected, %{state | attempts: state.attempts + 1}}
    end
  end

  # Handle Info functions
  @doc """
  Responds to node down events. Initiates leader election if the down node was the leader (:goose).

  ## Parameters
  - `{ :nodedown, node }`: Node down event with the node identifier.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, state}` with updated state.
  """
  @spec handle_info({:nodedown, pid()}, map()) :: {:noreply, map()}
  def handle_info({:nodedown, node}, state) do
    if node == state.leader do
      Logger.warn("Node down detected: #{inspect(node)}")
      Election.schedule(state)
    end

    {:noreply, %{state | leader: nil}}
  end

  @doc """
  Responds to node up events. Currently logs the event without state changes.

  ## Parameters
  - `{ :nodeup, _node }`: Node up event.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, state}` unchanged.
  """
  @spec handle_info({:nodeup, pid()}, map()) :: {:noreply, map()}
  def handle_info({:nodeup, _node}, state) do
    Logger.info("Node up detected...")
    {:noreply, state}
  end

  @doc """
  Triggers leader election and updates state accordingly.

  ## Parameters
  - `:elect_leader`: Request to initiate a leader election.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with potentially updated state after election.
  """
  @spec handle_info(:elect_leader, map()) :: {:noreply, map()}
  def handle_info(:elect_leader, state) do
    Logger.info("Handling leader election for any state...")
    new_state = Election.elect_leader(state)
    {:noreply, new_state}
  end

  @doc """
  Sends a heartbeat signal if the node is the current leader (goose).

  ## Parameters
  - `:send_heartbeat`: Command to send a heartbeat.
  - `state`: Current GenServer state, expected to be the leader (goose).

  ## Returns
  - `{:noreply, state}` with potentially rescheduled heartbeat timer.
  """
  @spec handle_info(:send_heartbeat, map()) :: {:noreply, map()}
  def handle_info(:send_heartbeat, state = %{role: @goose}) do
    Logger.debug("Sending heartbeat...")
    Broadcast.run(__MODULE__, :heartbeat, Node.self())
    new_state = Heartbeat.schedule(state)
    {:noreply, new_state}
  end

  @doc """
  Updates the leader information based on received heartbeats.

  ## Parameters
  - `{:heartbeat, leader}`: Heartbeat received with leader's node identifier.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with updated leader and potentially new heartbeat timer.
  """
  @spec handle_info({:heartbeat, pid()}, map()) :: {:noreply, map()}
  def handle_info({:heartbeat, leader}, state) do
    Logger.debug("Received heartbeat from leader: #{inspect(leader)}")

    if state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    new_timer = Process.send_after(self(), :heartbeat_timeout, heartbeat_timeout())
    {:noreply, %{state | leader: leader, heartbeat_timer: new_timer}}
  end

  @doc """
  Handles the cancellation of the heartbeat timer.

  ## Parameters
  - `:cancel_heartbeat_timer`: Command to cancel the current heartbeat timer.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, state}` with the heartbeat timer cleared.
  """
  @spec handle_info(:cancel_heartbeat_timer, map()) :: {:noreply, map()}
  def handle_info(:cancel_heartbeat_timer, state) do
    Process.cancel_timer(state.heartbeat_timer)

    {:noreply, %{state | heartbeat_timer: nil}}
  end

  @doc """
  Updates the GenServer state with a new leader when a leader update is received.

  ## Parameters
  - `{:leader_update, leader}`: Notification of a new leader.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with the leader updated in the state.
  """
  @spec handle_info({:leader_update, pid()}, map()) :: {:noreply, map()}
  def handle_info({:leader_update, leader}, state) do
    Logger.debug("New leader: #{inspect(leader)}")

    {:noreply, %{state | leader: leader}}
  end

  @doc """
  Updates the role of the node within the cluster.

  ## Parameters
  - `{:update_role, role}`: Command to update the node's role.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with the role updated in the state.
  """
  @spec handle_info({:update_role, atom()}, map()) :: {:noreply, map()}
  def handle_info({:update_role, role}, state) do
    {:noreply, %{state | role: role}}
  end

  @doc """
  Handles the timeout event indicating no heartbeat was received from the leader.

  ## Parameters
  - `:heartbeat_timeout`: Command indicating a timeout for heartbeat reception.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with the leader cleared and role reset, scheduling a new election.
  """
  @spec handle_info(:heartbeat_timeout, map()) :: {:noreply, map()}
  def handle_info(:heartbeat_timeout, state) do
    Logger.error("Heartbeat timeout reached. No heartbeat received from leader.")
    state = %{state | leader: nil, heartbeat_timer: nil, role: @duck}

    # Reschedules an election as the leader did not send any heartbeat before the timeout expire
    Election.schedule(state)
    {:noreply, state}
  end

  @doc """
  Receives and processes a heartbeat from the current leader, resetting the heartbeat timer.

  ## Parameters
  - `{:heartbeat, leader}`: Heartbeat received from the leader.
  - `state`: Current GenServer state.

  ## Returns
  - `{:noreply, new_state}` with updated heartbeat timer.
  """
  @spec handle_cast({:heartbeat, pid()}, map()) :: {:noreply, map()}
  def handle_cast({:heartbeat, leader}, state) do
    Logger.debug("Received heartbeat from leader: #{inspect(leader)}")

    # Cancel the current timer as the heartbeat was received
    if state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    new_timer = Process.send_after(self(), :heartbeat_timeout, heartbeat_timeout())
    {:noreply, %{state | leader: leader, heartbeat_timer: new_timer}}
  end

  # Helper function to fetch heartbeat timeout from config
  @doc false
  defp heartbeat_timeout(), do: Application.get_env(:duck_duck_goose, :heartbeat_timeout, 60_000)
end
