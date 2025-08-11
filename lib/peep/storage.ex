defmodule Ogle.Storage do
  @moduledoc """
  Behaviour for Ogle storage backends. These functions are mainly called by Ogle
  during normal functioning. Ordinary usage of Ogle should not require calling
  any of these functions.
  """
  alias Telemetry.Metrics

  @doc """
  Creates a new term representing a Ogle storage backend.
  """
  @callback new() :: term()

  @doc """
  Calculates the amount of memory used by a Ogle storage backend.
  """
  @callback storage_size(term()) :: %{size: non_neg_integer(), memory: non_neg_integer()}

  @doc """
  Stores a sample metric
  """
  @callback insert_metric(term(), Ogle.metric_id(), Metrics.t(), term(), map()) :: any()

  @doc """
  Retrieves all stored metrics
  """
  @callback get_all_metrics(term(), Ogle.Persistent.t()) :: map()

  @doc """
  Retrieves a single stored metric
  """
  @callback get_metric(term(), Ogle.metric_id(), Metrics.t(), map()) :: any()

  @doc """
  Removes metrics whose metadata contains a specific tag key and value.
  This is intended to improve situations where Ogle emits metrics whose tags
  have high cardinality.
  """
  @callback prune_tags(Enumerable.t(%{Metrics.tag() => term()}), map()) :: :ok
end
