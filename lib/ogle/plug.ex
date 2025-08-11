if Code.ensure_loaded?(Plug) do
  defmodule Ogle.Plug do
    @moduledoc """
    Use this plug to expose your metrics on an endpoint for scraping. This is useful if you are using Prometheus.

    This plug accepts the following options:

    * `:ogle_worker` - The name of the Ogle worker to use. This is required.
    * `:path` - The path to expose the metrics on. Defaults to `"/metrics"`.
    * `:on_unmatched_path` - The intended behavior of this plug when handling a
      request to a different path. There are two possible values:
        - `:continue` (default) - This allows for subsequent Plugs in a router to
          be executed. This option is useful when Ogle.Plug is part of a router
          for a Phoenix application, or a router that matches other paths after
          Ogle.Plug.

        - `:halt` - Responds to requests with 404. This option is useful when
          Ogle.Plug is used for serving metrics on a separate port, which is a
          practice that is encouraged by other libraries that export Prometheus
          metrics.

    ## Usage

    You can use this plug in your Phoenix endpoint like this:

      ```elixir
      plug Ogle.Plug, ogle_worker: :my_ogle_worker
      ```

    Or if you'd rather use a different path:

      ```elixir
      plug Ogle.Plug, path: "/my-metrics"
      ```

    If you are not using Phoenix, you can use it directly with Cowboy by adding this to your applications's supervision tree:

      ```elixir
      {Plug.Cowboy, scheme: :http, plug: Ogle.Plug, options: [port: 9000]}
      ```

    Similarly, if you are using Bandit, you can use it like so:

      ```elixir
      {Bandit, [
        scheme: :http,
        plug: {Ogle.Plug, ogle_worker: :my_app},
        port: 9000
      ]}
      ```
    """

    @behaviour Plug

    import Plug.Conn
    alias Plug.Conn
    require Logger

    @default_metrics_path "/metrics"

    @impl Plug
    def init(opts) do
      %{
        metrics_path: Keyword.get(opts, :path, @default_metrics_path),
        ogle_worker: Keyword.fetch!(opts, :ogle_worker),
        on_unmatched_path: Keyword.get(opts, :on_unmatched_path, :continue)
      }
    end

    @impl Plug
    def call(%Conn{request_path: metrics_path, method: "GET"} = conn, %{
          metrics_path: metrics_path,
          ogle_worker: ogle_worker
        }) do
      metrics =
        Ogle.get_all_metrics(ogle_worker)
        |> Ogle.Prometheus.export()

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, metrics)
      |> halt()
    rescue
      error ->
        Logger.error(Exception.format(:error, error, __STACKTRACE__))

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(503, "Service Unavailable")
        |> halt()
    end

    def call(%Conn{request_path: metrics_path} = conn, %{metrics_path: metrics_path}) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(400, "Invalid Request")
      |> halt()
    end

    def call(%Conn{} = conn, %{on_unmatched_path: :continue}) do
      conn
    end

    def call(%Conn{} = conn, %{on_unmatched_path: :halt}) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Not Found")
      |> halt()
    end
  end
end
