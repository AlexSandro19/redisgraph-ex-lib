defmodule RedisGraphTest do
  alias RedisGraph.Relationship
  alias RedisGraph.Graph
  alias RedisGraph.Node
  alias RedisGraph.QueryResult

  use ExUnit.Case

  @redis_address "redis://localhost:6379"

  # def build_sample_graph() do
  #   graph =
  #     Graph.new(%{
  #       name: "social"
  #     })

  #   john =
  #     Node.new(%{
  #       label: "person",
  #       properties: %{
  #         name: "John Doe",
  #         age: 33,
  #         gender: "male",
  #         status: "single"
  #       }
  #     })

  #   {graph, john} = Graph.add_node(graph, john)

  #   japan =
  #     Node.new(%{
  #       label: "country",
  #       properties: %{
  #         name: "Japan"
  #       }
  #     })

  #   {graph, japan} = Graph.add_node(graph, japan)

  #   relationship =
  #     Relationship.new(%{
  #       src_node: john,
  #       dest_node: japan,
  #       relation: "visited"
  #     })

  #   {:ok, graph} = Graph.add_relationship(graph, relationship)
  #   graph
  # end

  # test "creates an execution plan" do
  #   {:ok, conn} = Redix.start_link(@redis_address)

  #   sample_graph = build_sample_graph()

  #   {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
  #   %QueryResult{} = commit_result

  #   assert Map.get(commit_result.statistics, "Nodes created") == "2"
  #   assert Map.get(commit_result.statistics, "Relationships created") == "1"

  #   q = "MATCH (p:person)-[]->(j:place {purpose:\"pleasure\"}) RETURN p"
  #   {:ok, plan} = RedisGraph.execution_plan(conn, sample_graph.name, q)

  #   assert plan ==
  #            [
  #              "Results",
  #              "    Project",
  #              "        Conditional Traverse | (j:place)->(p:person)",
  #              "            Filter",
  #              "                Node By Label Scan | (j:place)"
  #            ]

  #   # cleanup
  #   {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
  #   assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
  # end

  # test "gets results from call procedures" do
  #   {:ok, conn} = Redix.start_link("redis://localhost:6379")

  #   sample_graph = build_sample_graph()

  #   {:ok, commit_result} = RedisGraph.commit(conn, sample_graph)
  #   %QueryResult{} = commit_result

  #   assert Map.get(commit_result.statistics, "Nodes created") == "2"
  #   assert Map.get(commit_result.statistics, "Relationships created") == "1"

  #   {:ok, labels_result} = RedisGraph.labels(conn, sample_graph.name)

  #   labels =
  #     labels_result
  #     |> Enum.at(1)
  #     |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

  #   assert "person" in labels
  #   assert "country" in labels

  #   {:ok, property_keys_result} = RedisGraph.property_keys(conn, sample_graph.name)

  #   property_keys =
  #     property_keys_result
  #     |> Enum.at(1)
  #     |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

  #   assert "age" in property_keys
  #   assert "gender" in property_keys
  #   assert "name" in property_keys
  #   assert "status" in property_keys

  #   {:ok, relationship_types_result} = RedisGraph.relationship_types(conn, sample_graph.name)

  #   relationship_types =
  #     relationship_types_result
  #     |> Enum.at(1)
  #     |> Enum.map(fn element -> element |> Enum.at(0) |> Enum.at(1) end)

  #   assert "visited" in relationship_types

  #   {:ok, delete_result} = RedisGraph.delete(conn, sample_graph.name)
  #   assert is_binary(Map.get(delete_result.statistics, "Query internal execution time"))
  # end

  setup_all do
    {atom, process_id} = Redix.start_link(@redis_address)
    graph = Graph.new(%{name: "test"})
    {atom, %{conn: process_id, graph: graph}}
  end

  setup context do
    on_exit(fn ->
      conn = context[:conn]
      graph = context[:graph]
      RedisGraph.delete(conn, graph.name)
    end)

    :ok
  end

  describe "RedisGraph.command" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      query = [
          "GRAPH.QUERY",
          graph.name,
          "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a",
          "--compact"
        ]

      {:ok, query_result} = RedisGraph.command(conn, query)
      %{result_set: result_set, header: header, statistics: statistics} = query_result

      correct_header = [:a]
      correct_result_set = [
        [
          %RedisGraph.Node{
            id: 0,
            alias: :a,
            labels: ["actor"],
            properties: %{name: "Hugh Jackman"}
          }
        ]
      ]

      assert is_struct(query_result, QueryResult)

      assert header == correct_header
      assert result_set == correct_result_set

      assert Map.get(statistics, "Nodes created") == "2"
      assert Map.get(statistics, "Properties set") == "2"
      assert Map.get(statistics, "Relationships created") == "1"

    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      query = [
          "GRAPH.QUERY",
          graph.name,
          "MATCH (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'})",
          "--compact"
        ]
      {:error, error} = RedisGraph.command(conn, query)
      assert is_struct(error, Redix.Error)
    end
  end

  describe "RedisGraph.query" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"

      {:ok, query_result} = RedisGraph.query(conn, graph.name, query)
      %{result_set: result_set, header: header, statistics: statistics} = query_result

      correct_header = [:a]
      correct_result_set = [
        [
          %RedisGraph.Node{
            id: 0,
            alias: :a,
            labels: ["actor"],
            properties: %{name: "Hugh Jackman"}
          }
        ]
      ]

      assert is_struct(query_result, QueryResult)

      assert header == correct_header
      assert result_set == correct_result_set

      assert Map.get(statistics, "Nodes created") == "2"
      assert Map.get(statistics, "Properties set") == "2"
      assert Map.get(statistics, "Relationships created") == "1"

    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      query = "MATCH (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'})"
      {:error, error} = RedisGraph.query(conn, graph.name, query)
      assert is_struct(error, Redix.Error)
    end
  end

  describe "RedisGraph.execution_plan" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      create_query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, create_query)

      match_query = "MATCH (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, query_result} = RedisGraph.execution_plan(conn, graph.name, match_query)

      response = query_result
      correct_response = [
        "Results",
        "    Project",
        "        Filter",
        "            Conditional Traverse | (a)->(m:movie)",
        "                Filter",
        "                    Node By Label Scan | (a:actor)"
      ]

      assert response == correct_response

    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      create_query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, create_query)

      match_query = "MATCH (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'})"
      {:error, error} = RedisGraph.execution_plan(conn, graph.name, match_query)
      assert is_struct(error, Redix.Error)

    end
  end

  describe "RedisGraph.delete" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      create_query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, create_query)
      {:ok, delete_result} = RedisGraph.delete(conn, graph.name)
      assert is_binary(Map.get(delete_result.statistics, "Graph removed, internal execution time"))
    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      create_query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, create_query)
      {:error, error} = RedisGraph.delete(conn, "1234")
      assert is_struct(error, Redix.Error)
    end
  end

  describe "RedisGraph.call_procedure" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"

      {:ok, _query_result} = RedisGraph.query(conn, graph.name, query)

      {:ok, query_result} = RedisGraph.call_procedure(conn, graph.name, "db.labels")
      %{result_set: result_set, header: header} = query_result

      correct_header = [:label]
      correct_result_set = [["actor"], ["movie"]]
      assert is_struct(query_result, QueryResult)
      assert header == correct_header
      assert result_set == correct_result_set
    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, query)
      {:error, error} = RedisGraph.call_procedure(conn, graph.name, "test")
      assert is_struct(error, Redix.Error)
    end
  end

  describe "RedisGraph.call_procedure_raw" do
    test "test that QueryResult is being returned with correct data", %{conn: conn, graph: graph} = _context do
      query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, query)
      {:ok, response} = RedisGraph.call_procedure_raw(conn, graph.name, "db.labels")
      assert is_list(response)

    end

    test "test that error is being returned", %{conn: conn, graph: graph} = _context do
      query = "CREATE (a:actor {name: 'Hugh Jackman'})-[:act]->(m:movie {title:'Wolverine'}) RETURN a"
      {:ok, _query_result} = RedisGraph.query(conn, graph.name, query)
      {:error, error} = RedisGraph.call_procedure_raw(conn, graph.name, "test")
      assert is_struct(error, Redix.Error)
    end
  end

end
