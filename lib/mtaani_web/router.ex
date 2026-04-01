defmodule MtaaniWeb.Router do
  use MtaaniWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MtaaniWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MtaaniWeb do
    pipe_through :browser

    # Main routes
    live "/", HomeLive, :index
    live "/explore", ExploreLive, :index
    live "/plan", PlanLive, :index
    live "/profile", ProfileLive, :index

    # Health check
    get "/health", PageController, :health
  end

  # WhatsApp webhook endpoint (for later)
  scope "/api", MtaaniWeb do
    pipe_through :api
    # post "/whatsapp", WhatsAppController, :webhook
    # get "/whatsapp", WhatsAppController, :verify
  end

  if Application.compile_env(:mtaani, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MtaaniWeb.Telemetry
    end
  end
end