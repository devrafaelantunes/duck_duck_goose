defmodule DuckDuckGoose.NodeManager.Heartbeat do
  @moduledoc """
  Manages heartbeat signals for the node.

  This module is responsible for scheduling regular heartbeat signals that help in
  maintaining the status and connectivity of the node within a cluster. It ensures
  that the node is active and can participate in leader elections and other cluster activities.
  """

  @doc """
  Schedules a heartbeat to be sent after a fixed interval.

  This function sets up a recurring heartbeat signal by scheduling the next heartbeat
  to be sent after a predefined interval (currently hardcoded to 1 second).

  ## Parameters
  - `state`: The current state of the node, which must include a `heartbeat_timer` field.

  ## Returns
  - The updated state with the new timer reference stored in `heartbeat_timer`.

  ## Examples

      iex> DuckDuckGoose.NodeManager.Heartbeat.schedule(%{heartbeat_timer: nil})
      %{heartbeat_timer: #Reference<0.0.1.100>}
  """
  @spec schedule(map()) :: map()
  def schedule(state) do
    new_timer = Process.send_after(self(), :send_heartbeat, 1000)
    %{state | heartbeat_timer: new_timer}
  end
end
