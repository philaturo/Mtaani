defmodule Mtaani.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MtaaniWeb.Telemetry,
      {Phoenix.PubSub, name: Mtaani.PubSub},
      MtaaniWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Mtaani.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MtaaniWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end