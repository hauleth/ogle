defmodule Ogle.Buckets do
  @moduledoc """
  A behavior for histogram bucketing strategies.

  You can pass a bucketing strategy to a distribution metric in your metrics:

  ```elixir
  def metrics do
    [
      distribution([:bandit, :request, :stop, :duration],
        tags: [],
        unit: {:native, :millisecond},
        reporter_options: [
          ogle_bucket_calculator: Ogle.Buckets.PowersOfTen
        ]
      )
    ]
  end
  ```

  If no bucketing strategy is provided is not set in :reporter_options for a
  `%Telemetry.Metrics.Distribution{}`, then the default is
  `Ogle.Buckets.Exponential`.

  You can change the default bucket calculator, set `:bucket_calculator` in your
  config.

  ```elixir
  config :ogle, bucket_calculator: Ogle.Buckets.PowersOfTen
  ```

  ## Custom Buckets

  If you want custom bucket boundaries, there is `Ogle.Buckets.Custom`, which
  uses pattern matching to assign sample measurements to buckets.

  Example:

  ```elixir
  defmodule MyApp.MyBucket do
    use Ogle.Buckets.Custom,
      buckets: [10, 100, 1_000]
  end
  ```
  """

  alias Telemetry.Metrics

  @default_module Application.compile_env(
                    :ogle,
                    :bucket_calculator,
                    Ogle.Buckets.Exponential
                  )

  @reporter_option :ogle_bucket_calculator

  @type config :: map

  @callback config(Metrics.Distribution.t()) :: config
  @callback number_of_buckets(config) :: pos_integer
  @callback bucket_for(number, config) :: non_neg_integer
  @callback upper_bound(non_neg_integer, config) :: String.t()

  @spec config(Metrics.Distribution.t()) :: {atom, config}
  def config(%Metrics.Distribution{reporter_options: opts} = metric) do
    module = Keyword.get(opts, @reporter_option, @default_module)
    {module, module.config(metric)}
  end
end
