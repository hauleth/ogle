defmodule PlugTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Telemetry.Metrics

  alias Ogle.Support.StorageCounter

  describe "init/1" do
    test "should raise an error if ogle_worker is not provided" do
      assert_raise KeyError, ~r/^key :ogle_worker not found.*/, fn ->
        Ogle.Plug.init([])
      end
    end

    test "should use the default path is one is not provided" do
      assert %{metrics_path: "/metrics"} = Ogle.Plug.init(ogle_worker: :my_ogle)
    end

    test "should return a map of all the settings if all are provided" do
      assert %{metrics_path: "/my-metrics", ogle_worker: :my_ogle} =
               Ogle.Plug.init(ogle_worker: :my_ogle, path: "/my-metrics")
    end
  end

  describe "call/2" do
    setup [:setup_ogle_worker]

    @tag :capture_log
    test "returns 503 if the metrics worker has not started", %{name: name} do
      stop_supervised!(name)
      opts = Ogle.Plug.init(ogle_worker: name)
      conn = conn(:get, "/metrics")
      response = Ogle.Plug.call(conn, opts)

      assert response.status == 503
      assert response.resp_body == "Service Unavailable"
    end

    test "returns metrics if the worker is running at the default path", %{name: name} do
      opts = Ogle.Plug.init(ogle_worker: name)
      conn = conn(:get, "/metrics")
      response = Ogle.Plug.call(conn, opts)

      assert response.status == 200
    end

    test "returns metrics if the worker is running at a custom path", %{name: name} do
      opts = Ogle.Plug.init(ogle_worker: name, path: "/my-metrics")
      conn = conn(:get, "/my-metrics")
      response = Ogle.Plug.call(conn, opts)

      assert response.status == 200
    end

    test "returns 400 for non-GET requests at metrics path", %{name: name} do
      opts = Ogle.Plug.init(ogle_worker: name)

      for method <- [:post, :put, :delete, :patch] do
        conn = conn(method, "/metrics")
        response = Ogle.Plug.call(conn, opts)

        assert response.status == 400
      end
    end

    test "returns 404 for non-metrics paths", %{name: name} do
      opts = Ogle.Plug.init(ogle_worker: name, on_unmatched_path: :halt)
      conn = conn(:get, "/not-metrics")
      response = Ogle.Plug.call(conn, opts)

      assert response.status == 404
    end

    test "does not halt for non-metrics paths by default", %{name: name} do
      opts = Ogle.Plug.init(ogle_worker: name)
      conn = conn(:get, "/not-metrics")
      response = Ogle.Plug.call(conn, opts)

      refute response.halted
    end
  end

  describe "servers" do
    test "Bandit" do
      name = :bandit_ogle
      metrics = [last_value("vm.memory.total", unit: :byte)]
      _ogle = start_supervised!({Ogle, name: name, metrics: metrics})
      plug = {Ogle.Plug, ogle_worker: name}
      port = 9001

      {:ok, _pid} = start_supervised({Bandit, plug: plug, port: port})

      assert {:ok, {{~c"HTTP/1.1", 200, ~c"OK"}, _, _}} =
               :httpc.request("http://localhost:#{port}/metrics")
    end

    test "Plug.Cowboy" do
      name = :cowboy_ogle
      metrics = [last_value("vm.memory.total", unit: :byte)]
      _ogle = start_supervised!({Ogle, name: name, metrics: metrics})
      plug = {Ogle.Plug, ogle_worker: name}
      port = 9002

      {:ok, _pid} =
        start_supervised({Plug.Cowboy, scheme: :http, plug: plug, options: [port: port]})

      assert {:ok, {{~c"HTTP/1.1", 200, ~c"OK"}, _, _}} =
               :httpc.request("http://localhost:#{port}/metrics")
    end
  end

  def setup_ogle_worker(context) do
    name = StorageCounter.fresh_id()

    start_supervised!(
      {Ogle, name: name, metrics: [last_value("vm.memory.total", unit: :byte)]},
      id: name
    )

    Map.put(context, :name, name)
  end
end
