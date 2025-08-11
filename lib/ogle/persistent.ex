defmodule Ogle.Persistent do
  @moduledoc false
  defstruct [:name, :storage, :events_to_metrics, :ids_to_metrics, :metrics_to_ids]

  @compile {:inline, key: 1, fetch: 1}

  @type name() :: atom()

  @typep storage_default() :: {Ogle.Storage.ETS, :ets.tid()}
  @typep storage_striped() :: {Ogle.Storage.Striped, %{pos_integer() => :ets.tid()}}
  @typep storage() :: storage_default() | storage_striped()
  @typep events_to_metrics() :: %{
           :telemetry.event_name() => [{Telemetry.Metrics.t(), non_neg_integer()}]
         }
  @typep ids_to_metrics :: %{Ogle.metric_id() => Telemetry.Metrics.t()}
  @typep metrics_to_ids :: %{Telemetry.Metrics.t() => Ogle.metric_id()}

  @type t() :: %__MODULE__{
          name: name(),
          storage: storage(),
          events_to_metrics: events_to_metrics(),
          ids_to_metrics: ids_to_metrics(),
          metrics_to_ids: metrics_to_ids()
        }

  @spec new(Ogle.Options.t()) :: t()
  def new(%Ogle.Options{} = options) do
    %Ogle.Options{name: name, storage: storage_impl, metrics: metrics} = options

    storage =
      case storage_impl do
        :default ->
          {Ogle.Storage.ETS, Ogle.Storage.ETS.new()}

        :striped ->
          {Ogle.Storage.Striped, Ogle.Storage.Striped.new()}
      end

    %{
      events_to_metrics: events_to_metrics,
      ids_to_metrics: ids_to_metrics,
      metrics_to_ids: metrics_to_ids
    } = Ogle.assign_metric_ids(metrics)

    %__MODULE__{
      name: name,
      storage: storage,
      events_to_metrics: events_to_metrics,
      ids_to_metrics: ids_to_metrics,
      metrics_to_ids: metrics_to_ids
    }
  end

  @spec store(t()) :: :ok
  def store(%__MODULE__{} = term) do
    %__MODULE__{name: name} = term
    :persistent_term.put(key(name), term)
  end

  @spec fetch(name()) :: t() | nil
  def fetch(name) when is_atom(name) do
    :persistent_term.get(key(name), nil)
  end

  @spec erase(name()) :: :ok
  def erase(name) when is_atom(name) do
    :persistent_term.erase(name)
    :ok
  end

  @spec storage(name()) :: {module(), term()} | nil
  def storage(name) when is_atom(name) do
    case fetch(name) do
      %__MODULE__{storage: s} ->
        s

      _ ->
        nil
    end
  end

  defmacro fast_fetch(name) when is_atom(name) do
    quote do
      :persistent_term.get(unquote(key(name)), nil)
    end
  end

  defp key(name) when is_atom(name) do
    {Ogle, name}
  end
end
