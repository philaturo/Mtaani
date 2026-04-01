defmodule Mtaani.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mtaani.Repo,
      {Phoenix.PubSub, name: Mtaani.PubSub},
      MtaaniWeb.OnlineTracker,
      MtaaniWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Mtaani.Supervisor]
    Supervisor.start_link(children, opts)
  end
end