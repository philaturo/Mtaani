defmodule MtaaniWeb.Router do
  use MtaaniWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MtaaniWeb.Layouts, :app}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug :require_authenticated_user
  end

  defp fetch_current_user(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id when is_integer(user_id) ->
        case Mtaani.Accounts.get_user(user_id) do
          nil -> assign(conn, :current_user, nil)
          user -> assign(conn, :current_user, user)
        end

      user_id when is_binary(user_id) ->
        case Integer.parse(user_id) do
          {int_id, ""} ->
            case Mtaani.Accounts.get_user(int_id) do
              nil -> assign(conn, :current_user, nil)
              user -> assign(conn, :current_user, user)
            end

          _ ->
            assign(conn, :current_user, nil)
        end
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

  # Public routes
  scope "/", MtaaniWeb do
    pipe_through :browser

    live "/auth", AuthLive, :index
    get "/health", PageController, :health
  end

  # Session routes - only GET for redirect after verification, POST removed since we use LiveView events
  scope "/", MtaaniWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    delete "/logout", SessionController, :delete
  end

  # Protected routes
  scope "/", MtaaniWeb do
    pipe_through [:browser, :require_auth]

    live "/", HomeLive, :index
    live "/map", MapLive, :index
    live "/chat", ChatLive, :index
    live "/groups", GroupsLive, :index
    live "/plan", PlanLive, :index
    live "/profile", ProfileLive, :index
    live "/profile/:username", ProfileLive, :index
  end

  # API routes
  scope "/api", MtaaniWeb do
    pipe_through :api
  end

  if Application.compile_env(:mtaani, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: MtaaniWeb.Telemetry
    end
  end
end
