defmodule DuckDuckGoose.NodeManagerTest do
  use ExUnit.Case, async: false
  alias DuckDuckGoose.NodeManager

  @manager_api DuckDuckGoose.NodeManager.API
  @total_nodes 5

  import ExUnit.CaptureLog

  describe "node is elected :goose/leader" do
    setup do
      # Starts the nodes
      nodes = LocalCluster.start_nodes("nodes", @total_nodes)
      # Waits for the election to complete
      :timer.sleep(5000)

      # Stops nodes when exiting the tests
      on_exit(fn -> LocalCluster.stop_nodes(nodes) end)
      :ok
    end

    test "only one node is elected :goose/leader" do
      nodes = Node.list()
      # Gets all the nodes' roles
      node_responses = get_responses(nodes)

      # Filters by the leader
      leader = filter_leader(node_responses)

      assert leader
      # Ensures there's only one leader present on the node
      assert length(leader) == 1
      assert length(node_responses) == @total_nodes
    end

    test "once a :goose dies another node is promoted" do
      nodes = Node.list()
      node_responses = get_responses(nodes)
      leader = filter_leader(node_responses) |> IO.inspect
      leader_node = leader |> hd() |> Map.get(:node)

      assert leader
      assert length(leader) == 1
      assert length(node_responses) == @total_nodes

      # Stops the leader node
      :ok = LocalCluster.stop_nodes([leader_node])

      :timer.sleep(5000)

      nodes = List.delete(nodes, leader_node)
      node_responses = get_responses(nodes)
      leader = filter_leader(node_responses)
      second_leader_node = leader |> hd() |> Map.get(:node)

      # Ensures the previous leader node is not the same as the current one
      refute second_leader_node == leader_node
      # Checks if there's only one leader present
      assert length(leader) == 1
      assert length(node_responses) == @total_nodes - 1
    end
  end

  describe "node role and state management" do
    test "dead :goose rejoins as a :duck" do
      [leader_node] = LocalCluster.start_nodes("leader_node", 1)

      # Promotes the node to leader (:goose)
      send({DuckDuckGoose.NodeManager, leader_node}, {:update_role, :goose})
      # Starts the heartbeat "cycle"
      send({DuckDuckGoose.NodeManager, leader_node}, :send_heartbeat)

      :timer.sleep(3000)

      _nodes = LocalCluster.start_nodes("nodes", 3)
      all_nodes = Node.list()

      node_responses = get_responses(all_nodes)

      # Finds the leader
      leader =
        Enum.find(node_responses, fn response ->
          response.node == leader_node
        end)

      # Checks that the node is a goose
      assert leader.role == :goose
      # Stops the current goose
      LocalCluster.stop_nodes([leader_node])

      :timer.sleep(3000)

      # Recreates the leader node
      [previous_leader_node] = LocalCluster.start_nodes("leader_node", 1)

      # Checks that the leader node is the same as the before
      assert leader_node == previous_leader_node

      all_nodes = Node.list()

      node_responses = get_responses(all_nodes)
      [leader] = filter_leader(node_responses)

      refute leader.node == previous_leader_node

      previous_leader =
        Enum.find(node_responses, fn response ->
          response.node == previous_leader_node
        end)

      # Checks that the previous leader is now a duck after rejoining
      assert previous_leader.role == :duck
    end
  end

  describe "logging test" do
    setup do
      :timer.sleep(1000)

      # Checks if the NodeManager is running and get its pid
      if GenServer.whereis(NodeManager) do
        # Stops the GenServer if it's running
        :ok = GenServer.stop(NodeManager)
      end

      # Starts a new instance of NodeManager
      {:ok, pid} = NodeManager.start_link([])

      # Returns the pid in the setup map
      {:ok, pid: pid}
    end

    test "logs initialization message", %{pid: pid} do
      assert capture_log(fn -> GenServer.call(pid, :get_role) end) =~
               "Handling request to get role"
    end

    test "logs on heartbeat timeout", %{pid: pid} do
      log =
        capture_log(fn ->
          send(pid, :heartbeat_timeout)
        end)

      assert log =~ "Heartbeat timeout reached. No heartbeat received from leader."
    end

    test "logs on receiving and handling vote requests", %{pid: pid} do
      # Simulates a call from the current node
      caller = Node.self()

      log =
        capture_log(fn ->
          GenServer.call(pid, {:vote_request, caller})
        end)

      assert log =~ "Handling vote request from #{inspect(caller)}"
    end

    test "logs on handling leader election", %{pid: pid} do
      log =
        capture_log(fn ->
          send(pid, :elect_leader)
        end)

      assert log =~ "Handling leader election for any state"
    end

    test "logs on successful leader election", %{pid: pid} do
      log =
        capture_log(fn ->
          send(pid, :elect_leader)
        end)

      assert log =~ "Electing leader"
    end
  end

  describe "state testing" do
    setup do
      {:ok, pid} = NodeManager.start_link([])
      {:ok, pid: pid}
    end

    test "grants vote when there is no leader", %{pid: pid} do
      caller = Node.self()

      log =
        capture_log(fn ->
          GenServer.call(pid, {:vote_request, caller})
        end)

      assert log =~ "Handling vote request from #{inspect(caller)}"
      state = :sys.get_state(pid)
      assert state.leader == caller
      assert state.attempts == 0
    end

    test "updates heartbeat timer on receiving heartbeat", %{pid: pid} do
      # Sets self as leader first
      send(pid, {:leader_update, Node.self()})
      original_timer = :sys.get_state(pid).heartbeat_timer

      log =
        capture_log(fn ->
          send(pid, {:heartbeat, Node.self()})
        end)

      assert log =~ "Received heartbeat from leader: #{inspect(Node.self())}"
      state = :sys.get_state(pid)
      assert state.heartbeat_timer != original_timer
    end

    test "handles leader updates correctly and logs the event", %{pid: pid} do
      new_leader = :"leader@127.0.0.1"

      # Captures the log and send the leader update message
      log =
        capture_log(fn ->
          send(pid, {:leader_update, new_leader})
        end)

      # Verifies the log contains the correct message
      assert log =~ "New leader: #{inspect(new_leader)}"

      assert :sys.get_state(pid).leader == new_leader
    end

    test "does not change state on node up", %{pid: pid} do
      original_state = :sys.get_state(pid)

      log =
        capture_log(fn ->
          send(pid, {:nodeup, Node.self()})
        end)

      assert log =~ "Node up detected"
      state = :sys.get_state(pid)
      assert state == original_state
    end

    test "resets leader on node down", %{pid: pid} do
      send(pid, {:leader_update, Node.self()})
      assert :sys.get_state(pid).leader == Node.self()

      log =
        capture_log(fn ->
          send(pid, {:nodedown, Node.self()})
        end)

      assert log =~ "Node down detected: #{inspect(Node.self())}"
      state = :sys.get_state(pid)
      assert state.leader == nil
    end

    test "rejects vote when there is a leader or role is not duck", %{pid: pid} do
      # Sets a leader and change role to goose
      send(pid, {:update_role, :goose})
      send(pid, {:leader_update, :"another_node@127.0.0.1"})

      # Ensures state update
      assert :sys.get_state(pid).role == :goose
      assert :sys.get_state(pid).leader == :"another_node@127.0.0.1"

      # Attempts to request vote
      caller = :"test_caller@127.0.0.1"

      log =
        capture_log(fn ->
          response = GenServer.call(pid, {:vote_request, caller})
          assert response == :rejected
        end)

      # Verifies log and check that the attempt counter incremented
      assert log =~ "Handling vote request from #{inspect(caller)}"
      assert :sys.get_state(pid).attempts == 1
    end

    test "resets state on heartbeat timeout", %{pid: pid} do
      # Sets a leader
      send(pid, {:leader_update, :"leader_node@127.0.0.1"})
      # Changes role to goose
      send(pid, {:update_role, :goose})
      # Sets a heartbeat timer
      send(pid, {:heartbeat, :"leader_node@127.0.0.1"})

      # Triggers a heartbeat timeout
      log =
        capture_log(fn ->
          send(pid, :heartbeat_timeout)
        end)

      # Verifies that the log shows the timeout error and checks state reset
      assert log =~ "Heartbeat timeout reached. No heartbeat received from leader."
      state = :sys.get_state(pid)
      assert state.leader == nil
      # Role should revert to duck
      assert state.role == :duck
      assert state.heartbeat_timer == nil
    end

    test "maintains consistent leader and state on node up", %{pid: pid} do
      send(pid, {:leader_update, :"existing_leader@127.0.0.1"})
      original_state = :sys.get_state(pid)

      log =
        capture_log(fn ->
          send(pid, {:nodeup, :"new_node@127.0.0.1"})
        end)

      # Verifies logs and state consistency
      assert log =~ "Node up detected"
      # Ensures no state change occurs
      assert :sys.get_state(pid) == original_state
    end

    test "handles simultaneous vote requests correctly", %{pid: pid} do
      caller1 = :"node1@127.0.0.1"
      caller2 = :"node2@127.0.0.1"

      Task.async(fn -> GenServer.call(pid, {:vote_request, caller1}) end)
      Task.async(fn -> GenServer.call(pid, {:vote_request, caller2}) end)

      :timer.sleep(100)

      state = :sys.get_state(pid)
      assert Enum.count([caller1, caller2], fn caller -> state.leader == caller end) == 1
    end
  end

  defp get_responses(nodes) do
    Enum.map(nodes, fn node ->
      :rpc.call(node, @manager_api, :fetch_role, [])
    end)
  end

  defp filter_leader(nodes) do
    Enum.filter(nodes, fn node ->
      node.role == :goose
    end)
  end
end
