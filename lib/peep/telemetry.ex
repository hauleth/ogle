defmodule Ogle.Telemetry do
  @moduledoc """
  `:telemetry` events for `Ogle` itself.

  ## Telemetry events

  - `[:ogle, :packet, :sent]`. Metadata contains `%{size: packet_size}`
  - `[:ogle, :packet, :error]`. Metadata contains `%{reason: reason}`
  """

  def sent_packet(size, :ok) do
    measurements = %{size: size}
    metadata = %{}
    :telemetry.execute([:ogle, :packet, :sent], measurements, metadata)
  end

  def sent_packet(_, {:error, reason}) do
    measurements = %{}
    metadata = %{reason: reason}
    :telemetry.execute([:ogle, :packet, :error], measurements, metadata)
  end

  def storage_size(sizes, name, mod) do
    measurements = sizes
    metadata = %{name: name, mod: mod}
    :telemetry.execute([:ogle, :storage], measurements, metadata)
  end
end
