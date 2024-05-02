defmodule DuckDuckGoose.Application do
  use Application

  require Logger

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) |> IO.inspect()
    port = find_available_port(from_port(), to_port())

    children = [
      {Cluster.Supervisor, [topologies, [name: DuckDuckGoose.ClusterSupervisor]]},
      DuckDuckGoose.NodeManager
    ]

    if Mix.env() != :test do
      children = children ++ [cowboy_child_spec(port)]

      Logger.info("Endpoint started on port: #{port}")
    end

    opts = [strategy: :one_for_one, name: DuckDuckGoose.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cowboy_child_spec(port) do
    dispatch = :cowboy_router.compile([{:_, DuckDuckGoose.Routes.routes()}])
    :persistent_term.put(:duck_duck_goose_dispatch, dispatch)

    %{
      id: :server,
      start: {
        :cowboy,
        :start_clear,
        [
          :server,
          %{
            socket_opts: [port: port],
            max_connections: 16_384,
            num_acceptors: 8
          },
          %{env: %{dispatch: {:persistent_term, :duck_duck_goose_dispatch}}}
        ]
      },
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor
    }
  end

  defp find_available_port(from_port, to_port) do
    Enum.find(from_port..to_port, &port_available?/1) || raise "No available ports"
  end

  # Checks for the available ports based on the range present on the config
  defp port_available?(port) do
    :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    |> case do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  defp from_port(), do: Application.get_env(:duck_duck_goose, :from_port, 3000)
  defp to_port(), do: Application.get_env(:duck_duck_goose, :to_port, 3100)
end
