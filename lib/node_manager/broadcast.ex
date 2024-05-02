defmodule DuckDuckGoose.NodeManager.Broadcast do
  @moduledoc """
  Handles broadcasting messages to other nodes within the Erlang node network.

  This module provides functionality to send a specified message under a given topic
  to all nodes registered under the same name but excluding the node itself.
  """

  require Logger

  @doc """
  Broadcasts a message to all other nodes registered under the given name.

  ## Parameters

  - `registered_name`: The registered name of the processes that should receive the message.
  - `topic`: The topic under which the message is sent.
  - `message`: The actual message to be sent.

  ## Examples

      iex> DuckDuckGoose.NodeManager.Broadcast.run(:my_service, :update, %{data: "new data"})
      :ok

  Sends the `message` with the specified `topic` to all other nodes except the node itself.

  Returns `:ok` after executing.
  """
  @spec run(atom(), atom(), any()) :: :ok
  def run(registered_name, topic, message) do
    Node.list()
    |> Enum.reject(&(&1 == Node.self()))
    |> Enum.each(fn node ->
      send({registered_name, node}, {topic, message})
    end)

    :ok
  end
end
