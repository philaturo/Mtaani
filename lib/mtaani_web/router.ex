defmodule MtaaniWeb.Router do
  use MtaaniWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MtaaniWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MtaaniWeb do
    pipe_through :browser

    # Our new minimalist home page, this will have a  modal/contextual AI interface
    live "/", HomeLive, :index
    
    # we are keeping this for health checks
    get "/health", PageController, :health
  end

  # WhatsApp webhook endpoint (for later)
  scope "/api", MtaaniWeb do
    pipe_through :api
    
    post "/whatsapp", WhatsAppController, :webhook
    get "/whatsapp", WhatsAppController, :verify
  end

  # Keep dev tools if in development
  if Application.compile_env(:mtaani, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MtaaniWeb.Telemetry
    end
  end
end