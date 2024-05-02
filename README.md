# DuckDuckGoose

### Overview

DuckDuckGoose is a distributed system designed to ensure consistent leadership within a cluster of nodes by dynamically electing a single node as the "Goose." All other nodes in the cluster are considered "Ducks." This system is inspired by the Raft consensus algorithm and is tailored to manage leadership seamlessly and efficiently within a distributed environment.

### Key Features
- **Leader Election:** Automatically elects a Goose from among the nodes. If the Goose node fails, another Duck is elected as the new Goose.
- **Failover and Recovery:** Handles node failures gracefully, promoting a Duck to Goose as needed. A rejoining node that was previously a Goose will become a Duck if another Goose is active.
- **Single Leadership Guarantee:** Ensures that there is always exactly one Goose, even in cases of network partitions, preventing split-brain scenarios.
- **HTTP Server on Each Node:** Every node runs an HTTP server with an endpoint to check whether the node is a Duck or a Goose.
System Design

### Leader Election
The election process begins at startup or when a node detects that the current Goose is unresponsive or dead. Nodes use a randomized delay to initiate election, reducing the chance of election conflicts. During the election:

1. Each node requests votes from other nodes.
2. A node wins the election by receiving a majority of the votes.
3. Upon election, the node sets itself as the Goose and begins sending regular heartbeats to all other nodes.


### Heartbeat Mechanism
The Goose sends heartbeat signals to all Ducks to maintain its authority and to confirm its operational status. If a Duck does not receive a heartbeat within a specified timeout:

1. It initiates a new election process to select a new Goose.

### Network Partition Handling
In the event of a network partition, the system ensures that only one Goose exists across partitions, based on the node that can maintain a majority of votes within its partition.

## Installation and Running the Project

**Requirements**
- Elixir 1.11 or later
- Erlang/OTP 23 or later

**Starting Nodes**
To start a node in the cluster, use the following command:

`iex --sname node_name -S mix`

Each node automatically selects an available port from a predefined range and announces its port when started to serve the HTTP server.

### Running Tests
To run the tests, execute:

`mix test`

### Available Configuration Parameters
**Minimum  Election Delay**
- **Key:** :min_election_delay
- **Default:** 500 ms
- **Description:** Specifies the minimum delay before initiating a new election process after detecting that the current leader (Goose) might be unresponsive. This delay helps to prevent election storms in unstable network conditions by spacing out the election attempts from different nodes.

**Maximum Election Delay**
- **Key:** :max_election_delay
- **Default:** 10,000 ms
- **Description:** Specifies the maximum delay for starting an election process. The actual delay is randomly selected between the minimum and maximum to further reduce the chance of collisions in election initiations across the cluster.
Heartbeat Timeout

**Heartbeat timeout**
- **Key:** :heartbeat_timeout
- **Default:** 60,000 milliseconds (60 seconds)
- **Description:** Sets the timeout for receiving a heartbeat from the current leader (Goose). If a heartbeat is not received within this interval, nodes will assume the leader is down and may initiate an election to choose a new leader. This setting is crucial for maintaining the health and responsiveness of the cluster.

**Modifying Configuration**
These parameters can be set in your Elixir application's configuration file (config/config.exs), specific to each environment.

### Usage

**HTTP Server Endpoints**
Each node hosts an HTTP server that provides a /status endpoint to check the current role of the node.

**Checking Node Status**

- Endpoint: /status
- Method: GET
- Response: `200 OK: Returns JSON indicating whether the node is a Duck or a Goose.`
- Example Response:
```
{ "role": "Goose" }
```

### Design Decisions

> **Inspired by Raft**
DuckDuckGoose's leader election and node role management are inspired by the Raft consensus algorithm, which is renowned for its simplicity and effectiveness in managing distributed systems. The Raft algorithm provides a framework to ensure that leadership is democratically elected and that data consistency is maintained across all nodes. In DuckDuckGoose, we've adapted these principles to fit a lighter and more specific use case: dynamically managing node roles within a resilient cluster.

> **Choosing Cowboy over Phoenix**
For the HTTP server component, we chose to use Cowboy, a small, fast, and modular HTTP server, over more extensive frameworks like Phoenix. This decision was driven by the following considerations:

1. Simplicity: Cowboy offers a straightforward approach to handling HTTP requests without the additional overhead of full-featured frameworks.
2. Lightweight: It provides the necessary functionalities without the extra layers that come with more comprehensive frameworks, making it ideal for our use case where each node runs its server.
3. Performance: Cowboy is known for its efficiency and low resource consumption, which is critical in a distributed system where every bit of performance matters.
System Resilience

> **Emphasizing resilience**
The design ensures that node failures do not disrupt the cluster's overall functionality. The system automatically handles the re-election of leaders and integrates failover mechanisms to maintain operational consistency.

### Planned Improvements

- Enhanced Unit Testing: More rigorous unit tests will be implemented to cover more edge cases and failure scenarios. I've used the LocalCluster library to help with testing but honestly, I feel like it can be better implemented. Currently we use `:timer.sleep` to wait for the election to complete, it would be better to have an indicator that would only run the tests once the election was completed rather a fixed timer, this causes the tests to fail if the election is not completed. This also delays the tests to complete.
- Add Unit Testing for the HTTP Server: Since the HTTP server is rather simple and it was not the focus of this project, I decided to spend more time adding the tests for the NodeManager, my idea is to Mock the HTTP Server and test its response.
- Dynamic Configuration: Enhancing the system to allow dynamic reconfiguration of node settings and parameters without needing a restart.
- Security Measures: Implementing security protocols to protect the nodes and communication within the cluster from unauthorized access and attacks.
- Monitoring and Metrics: Integrate comprehensive monitoring and metrics to provide insights into the system’s performance and operational status.