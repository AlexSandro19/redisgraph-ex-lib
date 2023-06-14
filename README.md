# Ex_RedisGraph

A [RedisGraph](https://redis.io/docs/stack/graph/) client library in Elixir with support for Cypher query building.

The library is developed on top of an existing [library](https://github.com/crflynn/redisgraph-ex),
written by Christopher Flynn, and provides additional functionality with refactored codebase to support
[RedisGraph result set](https://redis.io/docs/stack/graph/design/client_spec/).

Library is publishd to [Hex](https://hex.pm/packages/ex_redisgraph).

Documentation for the library can be found [here](https://hexdocs.pm/ex_redisgraph/RedisGraph.html).

## Installation
Add the `:ex_redisgraph` dependency to your `mix.exs` file. 
```elixir
defp deps() do
  [
    {:ex_redisgraph, "~> 0.1.0"}
  ]
end
```

To run `RedisGraph` locally with Docker, use

```bash
docker run -p 6379:6379 -it --rm redis/redis-stack-server
```

## Examples
Here is a simple example of how to use the library:

```elixir
alias RedisGraph.{Query, Graph, QueryResult}

# Create a connection using Redix
{:ok, conn} = Redix.start_link("redis://localhost:6379")

# Create a graph
graph = Graph.new(%{
  name: "social"
})

{:ok, query} = Query.new()
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
## License

Ex_RedisGraph is licensed under [MIT](https://github.com/AlexSandro19/redisgraph-ex-lib/blob/master/licenses/LICENSE_AlexSandro19.txt).