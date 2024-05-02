defmodule DuckDuckGoose.NodeManager.ElectionTest do
  use ExUnit.Case
  import Mimic

  import ExUnit.CaptureLog

  alias DuckDuckGoose.NodeManager.Election
  alias DuckDuckGoose.RpcWrapper

  setup do
    {:ok, _} = Application.ensure_all_started(:duck_duck_goose)

    Mimic.copy(Node)
    Mimic.copy(DuckDuckGoose.RpcWrapper)
    Mimic.copy(Process)
  end

  describe "schedule/1" do
    test "returns {:ok, :already_elected} if the node is still alive" do
      state = %{leader: :some_leader}
      expect(Node, :ping, fn _ -> :pong end)

      assert Election.schedule(state) == {:ok, :already_elected}
    end

    test "schedules an election if the leader is not responding" do
      state = %{leader: :some_leader}

      # Expect Node.ping to return :pang, indicating the leader is not responding
      expect(Node, :ping, fn _ -> :pang end)

      # Capture the log output during the function call
      log =
        capture_log(fn ->
          Election.schedule(state)
        end)

      # Assert that the log contains the expected message about scheduling the election
      assert log =~ "Scheduling leader election"
    end
  end

  describe "elect_leader/1" do
    test "elects itself as leader if it receives a majority of votes" do
      state = %{leader: :"manager@127.0.0.1", role: :goose}
      expect(Node, :list, fn -> [:node1, :node2, :node3] end)
      expect(RpcWrapper, :call, fn _, _, _, _ -> :granted end)

      result = Election.elect_leader(state)
      assert result.leader == Node.self()
      assert result.role == :goose
    end

    test "re-schedules election if not enough votes" do
      state = %{leader: :old_leader}
      expect(Node, :list, fn -> [:node1, :node2, :node3] end)
      expect(RpcWrapper, :call, fn _, _, _, _ -> :denied end)

      # Capture the log output during the function call
      log =
        capture_log(fn ->
          assert Election.elect_leader(state) == state
        end)

      # Assert that the log includes a message indicating that the election is being re-scheduled
      assert log =~ "Scheduling leader election"
    end
  end

  describe "majority_votes?/1" do
    test "returns true if votes are a majority" do
      votes = [:granted, :granted, :granted]
      assert Election.majority_votes?(votes) == true
    end

    test "returns false if votes are not a majority or no votes" do
      assert Election.majority_votes?([]) == false
    end
  end
end
