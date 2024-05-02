import Config

config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Gossip,
      config: [hosts: []]
    ]
  ]

import_config "#{Mix.env()}.exs"
