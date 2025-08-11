defmodule Ogle.EventHandler do
  @moduledoc false

  @compile :inline

  def attach(name) do
    %Ogle.Persistent{events_to_metrics: metrics_by_event} = Ogle.Persistent.fetch(name)
    module = Ogle.Codegen.module(name)

    for {event_name, _metrics} <- metrics_by_event do
      handler_id = handler_id(event_name, name)

      :ok =
        :telemetry.attach(
          handler_id,
          event_name,
          &module.handle_event/4,
          nil
        )

      handler_id
    end
  end

  def detach(handler_ids) do
    for id <- handler_ids, do: :telemetry.detach(id)
    :ok
  end

  defp handler_id(event_name, ogle_name) do
    {__MODULE__, ogle_name, event_name}
  end
end
