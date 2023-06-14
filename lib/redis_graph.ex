defmodule RedisGraph do
  @moduledoc """

  Query builder library that provides functions
  to construct Cypher queries to communicate with [RedisGraph](https://redis.io/docs/stack/graph/) database
  and interact with the entities through defined structures.

  The library is developed on top of an existing [library](https://github.com/crflynn/redisgraph-ex),
  written by Christopher Flynn, and provides additional functionality with refactored codebase to support
  [RedisGraph result set](https://redis.io/docs/stack/graph/design/client_spec/).

  To run `RedisGraph` locally with Docker, use

  ```bash
  docker run -p 6379:6379 -it --rm redis/redis-stack-server
  ```

  Here is a simple example of how to use the library:

  ```elixir
  alias RedisGraph.{Query, Graph, QueryResult}

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{
    name: "social"
  })

  {:ok, query} =
        Query.new()
        |> Query.create()
        |> Query.node(:n, ["Person"], %{age: 30, name: "John Doe", works: true})
        |> Query.relationship_from_to(:r, "TRAVELS_TO", %{purpose: "pleasure"})
        |> Query.node(:m, ["Place"], %{name: "Japan"})
        |> Query.return(:n)
        |> Query.return_property(:n, "age", :Age)
        |> Query.return(:m)
        |> Query.build_query()

  # query will hold
  # "CREATE (n:Person {age: 30, name: 'John Doe', works: true})-[r:TRAVELS_TO {purpose: 'pleasure'}]->(m:Place {name: 'Japan'}) RETURN n, n.age AS Age, m

  # Execute the query
  {:ok, query_result} = RedisGraph.query(conn, graph.name, query)

  # Get result set
  result_set = Map.get(query_result, :result_set)
  # result_set will hold
  # [
  #   [
  #     %RedisGraph.Node{
  #       id: 2,
  #       alias: :n,
  #       labels: ["Person"],
  #       properties: %{age: 30, name: "John Doe", works: true}
  #     },
  #     30,
  #     %RedisGraph.Node{
  #       id: 3,
  #       alias: :m,
  #       labels: ["Place"],
  #       properties: %{name: "Japan"}
  #     }
  #   ]
  # ]

  ```
  """

  alias RedisGraph.{QueryResult, Util}

  require Logger

  @type connection() :: GenServer.server()

  @doc """
  Execute arbitrary command against the database.

  https://redis.io/docs/stack/graph/commands/

  Query commands will be a list of strings. They
  will begin with either `GRAPH.QUERY`,
  `GRAPH.EXPLAIN`, `GRAPH.DELETE` etc.

  The next element will be the name of the graph.

  The third element will be the query command.

  Optionally pass the last element `--compact`
  for compact results.

  Returns a `RedisGraph.QueryResult` containing the result set
  and metadata associated with the query or error message.

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Create the query
  query = [
      "GRAPH.QUERY",
      graph.name,
      "MATCH (a:actor)-[:act]->(m:movie {title:'straight outta compton'}) RETURN a",
      "--compact"
    ]

  # Call the command
  {:ok, query_result} = RedisGraph.command(conn, query)
  ```
  """
  @spec command(connection(), list(String.t())) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def command(conn, c) do
    # Logger.debug(Enum.join(c, " "))
    IO.puts("c")
    IO.inspect(c)
    case Redix.command(conn, c) do
      {:ok, result} ->
        {:ok, QueryResult.new(%{conn: conn, graph_name: Enum.at(c, 1), raw_result_set: result})}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Run a query on a graph in the database.

  Returns a `RedisGraph.QueryResult` containing the result set
  and metadata associated with the query or error message.

  https://redis.io/commands/graph.query/

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Create the query
  query = "MATCH (a:actor)-[:act]->(m:movie {title:'straight outta compton'}) RETURN a"

  # Call the query
  {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
  ```
  """
  @spec query(connection(), String.t(), String.t()) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def query(conn, graph_name, q) do
    c = ["GRAPH.QUERY", graph_name, q, "--compact"]
    command(conn, c)
  end

  @doc """
  Fetch the execution plan for a query on a graph.

  Returns a raw result containing the query plan.

  https://redis.io/commands/graph.explain/

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Create the query
  query = "MATCH (a:actor)-[:act]->(m:movie {title:'straight outta compton'}) RETURN a"

  # Call the query
  {:ok, query_result} = RedisGraph.execution_plan(conn, graph.name, query)
  ```
  """
  @spec execution_plan(connection(), String.t(), String.t()) :: {:ok, list()} | {:error, any()}
  def execution_plan(conn, graph_name, q) do
    c = ["GRAPH.EXPLAIN", graph_name, q]

    case Redix.command(conn, c) do
      {:error, _reason} = error ->
        error

      {:ok, result} ->
        # Logger.debug(result)
        {:ok, result}
    end
  end

  @doc """
  Delete a graph from the database.

  Returns a `RedisGraph.QueryResult` containing the result set
  and metadata associated with the query or error message.

  https://redis.io/commands/graph.delete/

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.delete(conn, graph.name)
  ```
  """
  @spec delete(connection(), String.t()) ::
          {:ok, QueryResult.t()} | {:error, any()}
  def delete(conn, graph_name) do
    command = ["GRAPH.DELETE", graph_name]
    RedisGraph.command(conn, command)
  end

  @doc """
  Execute a procedure call against the graph specified and receive the raw result of the procedure call.

  https://redis.io/docs/stack/graph/design/client_spec/#procedure-calls

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.call_procedure_raw(conn, graph.name, "db.labels")
  ```
  """
  @spec call_procedure_raw(connection(), String.t(), String.t(), list(), map()) :: {:ok, list()} | {:error, any()}
  def call_procedure_raw(conn, graph_name, procedure, args \\ [], kwargs \\ %{}) do
    args = Enum.map_join(args, ",", &Util.value_to_string/1)

    yields = Map.get(kwargs, "y", [])

    yields =
      if length(yields) > 0 do
        " YIELD " <> Enum.join(yields, ",")
      else
        ""
      end

    q = "CALL " <> procedure <> "(" <> args <> ")" <> yields
    c = ["GRAPH.QUERY", graph_name, q, "--compact"]

    case Redix.command(conn, c) do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Execute a procedure call against the graph specified.

  Returns a `RedisGraph.QueryResult` containing the result set
  and metadata associated with the query or error message.

  https://redis.io/docs/stack/graph/design/client_spec/#procedure-calls

  ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.call_procedure(conn, graph.name, "db.labels")
  ```
  """
  @spec call_procedure(connection(), String.t(), String.t(), list(), map()) :: {:ok, QueryResult.t()} | {:error, any()}
  def call_procedure(conn, graph_name, procedure, args \\ [], kwargs \\ %{}) do
    args = Enum.map_join(args, ",", &Util.value_to_string/1)

    yields = Map.get(kwargs, "y", [])

    yields =
      if length(yields) > 0 do
        " YIELD " <> Enum.join(yields, ",")
      else
        ""
      end

    q = "CALL " <> procedure <> "(" <> args <> ")" <> yields
    c = ["GRAPH.QUERY", graph_name, q, "--compact"]

    RedisGraph.command(conn, c)
  end

  @doc """
  Fetch response of the `db.labels()` procedure call against the specified graph.
  It returns a `RedisGraph.QueryResult` containing the result set and metadata from the call.
    ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.labels(conn, graph.name)
  ```
  """
  @spec labels(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def labels(conn, graph_name) do
    call_procedure(conn, graph_name, "db.labels")
  end

  @doc """
  Fetch response of the `db.relationshipTypes()` procedure call against the specified graph.
  It returns a `RedisGraph.QueryResult` containing the result set and metadata from the call.
    ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.relationship_types(conn, graph.name)
  ```
  """
  @spec relationship_types(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def relationship_types(conn, graph_name) do
    call_procedure(conn, graph_name, "db.relationshipTypes")
  end

  @doc """
  Fetch response of the `db.propertyKeys()` procedure call against the specified graph.
  It returns a `RedisGraph.QueryResult` containing the result set and metadata from the call.
    ## Example:
  ```
  alias RedisGraph.Graph

  # Create a connection using Redix
  {:ok, conn} = Redix.start_link("redis://localhost:6379")

  # Create a graph
  graph = Graph.new(%{name: "imdb"})

  # Call the query
  {:ok, query_result} = RedisGraph.property_keys(conn, graph.name)
  ```
  """
  @spec property_keys(connection(), String.t()) :: {:ok, list()} | {:error, any()}
  def property_keys(conn, graph_name) do
    call_procedure(conn, graph_name, "db.propertyKeys")
  end
end
