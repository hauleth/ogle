# Ogle

[![Hex version badge](https://img.shields.io/hexpm/v/ogle)](https://hex.pm/packages/ogle)
[![Hexdocs badge](https://img.shields.io/static/v1?message=hexdocs&label=&color=B1A5EE)](https://hexdocs.pm/ogle)
[![Elixir CI badge](https://github.com/hauleth/ogle/actions/workflows/elixir.yml/badge.svg)](https://github.com/hauleth/ogle/actions/workflows/elixir.yml)
[![Hex licence badge](https://img.shields.io/hexpm/l/ogle)](./LICENSE)

`Telemetry.Metrics` reporter for Prometheus and StatsD (including Datadog).

Ogle has some important differences from libraries like
`TelemetryMetricsPrometheus.Core` and `TelemetryMetricsStatsd`:

- Instead of sampling or on-demand aggregation of samples, Ogle estimates
  distributions using histograms.
- Instead of sending one datagram per telemetry event, Ogle's StatsD reporting
  runs periodically, batching all lines into the smallest number of datagram
  packets possible while still obeying the configured `:mtu` setting.

To use it, start a reporter with `start_link/1`, providing a keyword list of
options (see `Ogle.Options` for the schema against which options are validated).

```elixir
import Telemetry.Metrics

Ogle.start_link(
  name: MyOgle,
  metrics: [
    counter("http.request.count"),
    sum("http.request.payload_size"),
    last_value("vm.memory.total")
  ]
)
```

or put it under a supervisor:

```elixir
import Telemetry.Metrics

children = [
  {Ogle, [
    name: MyOgle,
    metrics: [
      counter("http.request.count"),
      sum("http.request.payload_size"),
      last_value("vm.memory.total")
    ]
  ]}
]

Supervisor.start_link(children, ...)
```

By default, Ogle does not emit StatsD data. It can be enabled by passing in
configuration with the `statsd` keyword. Ogle's StatsD reporting supports Unix
Domain Sockets.

## What's Missing

Currently, there's no implementation of 'summary' metrics. Since histograms are
relatively inexpensive in Ogle, we suggest you use 'distribution' metrics
instead.

## Installation

Ogle package can be installed by adding `ogle` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ogle, "~> 1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ogle>.
