defmodule Codegen.Test do
  use ExUnit.Case

  alias Ogle.Support.StorageCounter
  alias Telemetry.Metrics

  defp metrics do
    counter = Metrics.counter("ogle.counter", event_name: [:counter])
    sum = Metrics.sum("ogle.sum", event_name: [:sum], measurement: :count)

    last_value =
      Metrics.last_value("ogle.gauge", event_name: [:gauge], measurement: :value)

    distribution =
      Metrics.distribution("ogle.dist",
        event_name: [:dist],
        measurement: :value,
        reporter_options: [max_value: 100]
      )

    [counter, sum, last_value, distribution]
  end

  test "module exists after Ogle starts" do
    name = StorageCounter.fresh_id()

    options = [
      name: name,
      metrics: metrics()
    ]

    assert {:ok, _pid} = Ogle.start_link(options)
    module = Ogle.Codegen.module(name)

    for {%{event_name: event_name} = metric, id} <- metrics() do
      assert module.metrics(event_name) == [{metric, id}]
    end
  end
end
