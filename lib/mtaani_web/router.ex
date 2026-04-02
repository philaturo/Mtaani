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

  # Authentication pipeline
  pipeline :require_auth do
    plug :fetch_current_user
    plug :require_authenticated_user
  end

  defp fetch_current_user(conn, _opts) do
    if user_id = get_session(conn, :user_id) do
      user = Mtaani.Accounts.get_user(user_id)
      assign(conn, :current_user, user)
    else
      assign(conn, :current_user, nil)
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Please sign in to continue")
      |> redirect(to: "/auth")
      |> halt()
    end
  end

  # Public routes (no authentication required)
  scope "/", MtaaniWeb do
    pipe_through :browser

    live "/auth", AuthLive, :index
    get "/health", PageController, :health
  end

  # Login POST endpoint
  scope "/", MtaaniWeb do
    pipe_through :browser

    post "/login", SessionController, :create
    get "/login", SessionController, :new
  end

  # Protected routes (authentication required)
  scope "/", MtaaniWeb do
    pipe_through [:browser, :require_auth]

    live "/", HomeLive, :index
    live "/map", MapLive, :index
    live "/chat", ChatLive, :index
    live "/groups", GroupsLive, :index
    live "/plan", PlanLive, :index

    get "/logout", SessionController, :delete
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