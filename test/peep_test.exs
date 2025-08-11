defmodule OgleTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  doctest Ogle

  alias Telemetry.Metrics

  test "a worker can be started" do
    options = [
      name: __MODULE__,
      metrics: []
    ]

    assert {:ok, pid} = Ogle.start_link(options)
    assert Process.alive?(pid)
  end

  test "many workers can be started" do
    for i <- 1..10 do
      options = [
        name: :"#{__MODULE__}_#{i}",
        metrics: []
      ]

      assert {:ok, pid} = Ogle.start_link(options)
      assert Process.alive?(pid)
    end
  end

  test "a worker with no statsd config has no statsd state" do
    options = [
      name: :"#{__MODULE__}_no_statsd",
      metrics: []
    ]

    assert {:ok, pid} = Ogle.start_link(options)
    assert match?(%{statsd_state: nil}, :sys.get_state(pid))
  end

  test "a worker with non-empty global_tags applies to all metrics" do
    name = :"#{__MODULE__}_global_tags"

    tags = %{foo: "bar", baz: "quux", service: "my-app", env: "production"}
    tag_keys = [:foo, :baz]

    counter = Metrics.counter("ogle.counter", event_name: [:counter], tags: tag_keys)
    sum = Metrics.sum("ogle.sum", event_name: [:sum], measurement: :count, tags: tag_keys)

    last_value =
      Metrics.last_value("ogle.gauge", event_name: [:gauge], measurement: :value, tags: tag_keys)

    distribution =
      Metrics.distribution("ogle.dist",
        event_name: [:dist],
        measurement: :value,
        tags: tag_keys,
        reporter_options: [max_value: 100]
      )

    metrics = [counter, sum, last_value, distribution]

    options = [
      name: name,
      metrics: metrics,
      global_tags: tags
    ]

    assert {:ok, _pid} = Ogle.start_link(options)
    :telemetry.execute([:counter], %{})
    :telemetry.execute([:sum], %{count: 5})
    :telemetry.execute([:gauge], %{value: 10})
    :telemetry.execute([:dist], %{value: 15})

    assert Ogle.get_metric(name, counter, tags) == 1
    assert Ogle.get_metric(name, sum, tags) == 5
    assert Ogle.get_metric(name, last_value, tags) == 10
    assert Ogle.get_metric(name, distribution, tags).sum == 15
  end

  test "Ogle process name can be used with Ogle.Storage" do
    name = :"#{__MODULE__}_storage"

    options = [
      name: name,
      metrics: [
        Metrics.counter("another.ogle.counter", event_name: [:another, :counter]),
        Metrics.sum("another.ogle.sum", event_name: [:another, :sum], measurement: :count)
      ]
    ]

    {:ok, _pid} = Ogle.start_link(options)

    :telemetry.execute([:another, :counter], %{})
    :telemetry.execute([:another, :sum], %{count: 10})
    assert %{} = Ogle.get_all_metrics(name)
  end

  test "Summary metrics are dropped" do
    name = :"#{__MODULE__}_unsupported"

    options = [
      name: name,
      metrics: [
        Metrics.summary("ogle.summary"),
        Metrics.summary("another.ogle.summary")
      ]
    ]

    logs =
      capture_log(fn ->
        {:ok, _pid} = Ogle.start_link(options)
      end)

    assert %{} == Ogle.get_all_metrics(name)

    for event_name <- [[:ogle, :summary], [:another, :ogle, :summary]] do
      assert String.contains?(logs, "Dropping #{inspect(event_name)}")
    end
  end

  test "Handlers are detached on shutdown" do
    prefix = [:ogle, :shutdown_test]

    metric =
      Metrics.counter(prefix ++ [:counter])

    {:ok, options} =
      [
        name: :"#{__MODULE__}_shutdown_test",
        metrics: [metric]
      ]
      |> Ogle.Options.validate()

    {:ok, pid} = GenServer.start(Ogle, options, name: options.name)

    assert length(:telemetry.list_handlers(prefix)) == 1

    GenServer.stop(pid, :shutdown)

    assert [] == :telemetry.list_handlers(prefix)
  end

  test "assign_ids" do
    metrics =
      [c, s, d, l] = [
        Metrics.counter("one.two"),
        Metrics.sum("one.two"),
        Metrics.distribution("three.four"),
        Metrics.last_value("five.six")
      ]

    expected_by_event = %{
      [:one] => [{c, 1}, {s, 2}],
      [:three] => [{d, 3}],
      [:five] => [{l, 4}]
    }

    expected_by_id = %{1 => c, 2 => s, 3 => d, 4 => l}
    expected_by_metric = %{c => 1, s => 2, d => 3, l => 4}

    %{
      events_to_metrics: actual_by_event,
      ids_to_metrics: actual_by_id,
      metrics_to_ids: actual_by_metric
    } = Ogle.assign_metric_ids(metrics)

    assert actual_by_event == expected_by_event
    assert actual_by_id == expected_by_id
    assert actual_by_metric == expected_by_metric
  end

  test "Non-numeric values are dropped" do
    name = :"#{__MODULE__}_non_numeric_values"

    sum = Metrics.sum("#{name}.sum", event_name: [name, :sum], measurement: :value)

    last_value =
      Metrics.last_value("#{name}.last_value",
        event_name: [name, :last_value],
        measurement: :value
      )

    dist =
      Metrics.distribution(
        "#{name}.dist",
        event_name: [name, :dist],
        measurement: :value
      )

    metrics = [sum, last_value, dist]

    options = [
      name: name,
      metrics: metrics
    ]

    {:ok, _pid} = Ogle.start_link(options)

    :telemetry.execute([name, :sum], %{value: :foo})
    :telemetry.execute([name, :last_value], %{value: "bar"})
    :telemetry.execute([name, :dist], %{value: []})

    assert Ogle.get_metric(name, sum, []) == 0
    assert Ogle.get_metric(name, last_value, []) == nil
    assert Ogle.get_metric(name, dist, []) == nil
  end
end
