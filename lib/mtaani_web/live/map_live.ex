defmodule MtaaniWeb.MapLive do
  use MtaaniWeb, :live_view
  alias Mtaani.Repo
  alias Mtaani.Places.Place
  alias Mtaani.SafetyZones.SafetyZone
  alias Mtaani.Accounts.User
  alias MtaaniWeb.BottomNav
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    end

    socket =
      socket
      |> assign(:active_tab, "map")
      |> assign(:show_emergency, false)
      |> assign(:places, [])
      |> assign(:activity_zones, [])
      |> assign(:selected_place, nil)
      |> assign(:user_location, nil)
      |> assign(:current_filter, nil)
      |> assign(:bottom_sheet_open, false)
      |> assign(:layers_panel_open, false)
      |> assign(:current_user, socket.assigns[:current_user])
      |> assign(:search_query, "")
      |> assign(:map_layers, %{
        pulse: true,
        verified_spots: true,
        guides_online: true,
        events_today: false,
        community_pins: true,
        matatu_routes: false,
        weather: false,
        road_works: false
      })
      |> assign(:map_style, "explore")
      |> assign(:nearby_guides, [])

    {:ok, socket}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_event("user_location_update", %{"lat" => lat, "lng" => lng}, socket) do
    socket = assign(socket, :user_location, %{lat: lat, lng: lng})

    {:noreply,
     socket
     |> load_nearby_places(lat, lng)
     |> load_activity_zones(lat, lng)
     |> load_nearby_guides(lat, lng)}
  end

  @impl true
  def handle_event("filter_places_by_category", %{"category" => category}, socket) do
    socket = assign(socket, :current_filter, category)

    if socket.assigns.user_location do
      {:noreply,
       load_nearby_places(
         socket,
         socket.assigns.user_location.lat,
         socket.assigns.user_location.lng
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("place_selected", %{"place_id" => place_id}, socket) do
    place_id_int = String.to_integer(place_id)
    place = Enum.find(socket.assigns.places, fn p -> p.id == place_id_int end)
    {:noreply, assign(socket, selected_place: place, bottom_sheet_open: true)}
  end

  @impl true
  def handle_event("map_clicked", _params, socket) do
    {:noreply, assign(socket, bottom_sheet_open: false, selected_place: nil)}
  end

  @impl true
  def handle_event("toggle_bottom_sheet", _params, socket) do
    {:noreply, assign(socket, bottom_sheet_open: !socket.assigns.bottom_sheet_open)}
  end

  @impl true
  def handle_event("open_layers_panel", _params, socket) do
    {:noreply, assign(socket, layers_panel_open: true)}
  end

  @impl true
  def handle_event("close_layers_panel", _params, socket) do
    {:noreply, assign(socket, layers_panel_open: false)}
  end

  @impl true
  def handle_event("zoom_in", _params, socket) do
    {:noreply, push_event(socket, "zoom_in", %{})}
  end

  @impl true
  def handle_event("zoom_out", _params, socket) do
    {:noreply, push_event(socket, "zoom_out", %{})}
  end

  @impl true
  def handle_event("reset_north", _params, socket) do
    {:noreply, push_event(socket, "reset_north", %{})}
  end

  @impl true
  def handle_event("select_map_style", %{"style" => style}, socket) do
    socket = assign(socket, :map_style, style)
    {:noreply, push_event(socket, "change_map_style", %{style: style})}
  end

  @impl true
  def handle_event("toggle_layer", %{"layer" => layer}, socket) do
    layers = socket.assigns.map_layers
    updated_layers = Map.update!(layers, String.to_existing_atom(layer), fn v -> !v end)
    socket = assign(socket, :map_layers, updated_layers)

    {:noreply,
     push_event(socket, "toggle_layer", %{
       layer: layer,
       visible: updated_layers[String.to_existing_atom(layer)]
     })}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search_query: query)}
  end

  # Emergency handlers
  @impl true
  def handle_event("open_emergency", _, socket),
    do: {:noreply, assign(socket, :show_emergency, true)}

  @impl true
  def handle_event("close_emergency", _, socket),
    do: {:noreply, assign(socket, :show_emergency, false)}

  # Online tracking handlers
  @impl true
  def handle_event("user_online", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.add_user(user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("user_offline", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.remove_user(user_id)
    {:noreply, socket}
  end

  # Geolocation error handler
  @impl true
  def handle_event("location_error", %{"error" => error}, socket) do
    IO.puts("Geolocation error: #{error}")
    # Default to Nairobi center when location is denied
    {:noreply, push_event(socket, "center_on_nairobi", %{})}
  end

  # Alternative location update handler (matches profile_setup_live)
  @impl true
  def handle_event("location-update", %{"lat" => lat, "lng" => lng}, socket) do
    # Reuse the existing user_location_update handler
    handle_event("user_location_update", %{"lat" => lat, "lng" => lng}, socket)
  end

  # Private helper functions
  defp load_nearby_places(socket, lat, lng) do
    sql = """
    SELECT id, name, category, description, address, phone, price_range, safety_score, verified,
           ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat
    FROM places
    WHERE location IS NOT NULL
    ORDER BY ST_Distance(location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)
    LIMIT 50
    """

    places_data =
      case Ecto.Adapters.SQL.query(Repo, sql, [lng, lat]) do
        {:ok, result} ->
          Enum.map(result.rows, fn row ->
            %{
              id: Enum.at(row, 0),
              name: Enum.at(row, 1),
              category: Enum.at(row, 2),
              description: Enum.at(row, 3),
              address: Enum.at(row, 4),
              price_range: Enum.at(row, 7),
              safety_score: Enum.at(row, 8),
              verified: Enum.at(row, 9),
              location: %{
                type: "Point",
                coordinates: [Enum.at(row, 10), Enum.at(row, 11)]
              }
            }
          end)

        {:error, _} ->
          []
      end

    places_data =
      if socket.assigns.current_filter do
        Enum.filter(places_data, fn p -> p.category == socket.assigns.current_filter end)
      else
        places_data
      end

    socket
    |> assign(:places, places_data)
    |> push_event("places_loaded", %{places: places_data})
  end

  defp load_activity_zones(socket, _lat, _lng) do
    zones = Repo.all(from(z in SafetyZone, where: not is_nil(z.area), limit: 100))

    formatted_zones =
      Enum.map(zones, fn zone ->
        %{
          id: zone.id,
          name: zone.name,
          description: zone.description,
          safety_level: zone.safety_level,
          incident_count: zone.incident_count,
          area:
            case zone.area do
              %Geo.Polygon{} ->
                %{
                  type: "Polygon",
                  coordinates: zone.area.coordinates
                }

              _ ->
                nil
            end
        }
      end)

    socket
    |> assign(:activity_zones, zones)
    |> push_event("activity_zones_loaded", %{zones: formatted_zones})
  end

  defp get_user_initial(assigns) do
    case assigns[:current_user] do
      %{name: name} when is_binary(name) and name != "" ->
        name |> String.split() |> List.first() |> String.at(0) |> String.upcase()

      %{username: username} when is_binary(username) and username != "" ->
        String.at(username, 0) |> String.upcase()

      _ ->
        "PA"
    end
  end

  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  defp get_avatar_color(id) do
    colors = ["#10b981", "#3b82f6", "#8b5cf6", "#f59e0b", "#e11d48", "#0891b2", "#6366f1"]
    index = rem(id, length(colors))
    Enum.at(colors, index)
  end

  defp load_nearby_guides(socket, lat, lng) do
    guides = Mtaani.Accounts.get_nearby_guides(lat, lng, 10)

    formatted_guides =
      Enum.map(guides, fn user ->
        %{
          id: user.id,
          name: user.name,
          username: user.username,
          initials: get_initials(user.name),
          profile_photo_url: user.profile_photo_url,
          rating: user.guide.rating,
          total_tours: user.guide.total_tours,
          hourly_rate: user.guide.hourly_rate,
          availability_status: user.guide.availability_status,
          languages: user.guide.languages,
          area: user.location || "Nairobi Area"
        }
      end)

    assign(socket, :nearby_guides, formatted_guides)
  end

  defp get_tab_class(current_filter, category) do
    base = "tab-pill"

    if current_filter == category do
      base <> " active"
    else
      base
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="frame">
      <!-- Map Canvas with MapLibre -->
      <div id="map" phx-hook="MapLibre" class="map-canvas"></div>
      
    <!-- Top Bar -->
      <div class="topbar">
        <div class="search-row">
          <div class="search-card">
            <span class="s-icon">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
            </span>
            
            <input
              type="text"
              id="searchInput"
              placeholder="Search Nairobi, East Africa..."
              phx-keyup="search"
              phx-debounce="300"
              value={@search_query}
            />
            <span class="s-mic">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z"
                />
              </svg>
            </span>
          </div>
          
          <div class="av-btn" phx-click="navigate" phx-value-page="profile">
            {get_user_initial(assigns)}
          </div>
        </div>
        
        <div class="tabs-row">
          <button
            phx-click="filter_places_by_category"
            phx-value-category={nil}
            class={get_tab_class(@current_filter, nil)}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
                />
              </svg>
            </span>
            Set home
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="restaurant"
            class={get_tab_class(@current_filter, "restaurant")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.87c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513m-3-4.87v-1.5m-6 1.5v-1.5m12 9.75l-4.5-4.5M5.25 12l4.5 4.5m-4.5 0l4.5-4.5"
                />
              </svg>
            </span>
            Eat
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="hotel"
            class={get_tab_class(@current_filter, "hotel")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5M9 12h1.5M9 17.25h1.5M13.5 6.75h1.5M13.5 12h1.5M13.5 17.25h1.5"
                />
              </svg>
            </span>
            Stay
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="attraction"
            class={get_tab_class(@current_filter, "attraction")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
                />
              </svg>
            </span>
            Explore
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="cafe"
            class={get_tab_class(@current_filter, "cafe")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.75 8.25V6a2.25 2.25 0 00-2.25-2.25h-6A2.25 2.25 0 005.25 6v2.25m10.5 0H18a2.25 2.25 0 012.25 2.25v2.25a2.25 2.25 0 01-2.25 2.25h-2.25m-10.5 0H6a2.25 2.25 0 01-2.25-2.25V10.5A2.25 2.25 0 016 8.25h2.25m10.5 0V18a2.25 2.25 0 01-2.25 2.25h-6A2.25 2.25 0 018.25 18v-2.25"
                />
              </svg>
            </span>
            Coffee
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="fuel"
            class={get_tab_class(@current_filter, "fuel")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003.001 2.48z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18a3.75 3.75 0 00.75-7.357 4.001 4.001 0 01-1.5 0A3.75 3.75 0 0012 18z"
                />
              </svg>
            </span>
            Fuel
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="matatu"
            class={get_tab_class(@current_filter, "matatu")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.22-1.113-.615-1.53a15.014 15.014 0 00-6.135-3.256M6.75 13.5l.371 1.481A.75.75 0 007.835 15h4.33a.75.75 0 00.714-.519l.371-1.481"
                />
              </svg>
            </span>
            Matatu
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="health"
            class={get_tab_class(@current_filter, "health")}
          >
            <span class="tab-icon">
              <svg
                class="w-3.5 h-3.5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
                />
              </svg>
            </span>
            Health
          </button>
        </div>
      </div>
      
    <!-- Map Controls -->
      <div class="map-ctrl">
        <div class="mc-btn" phx-click="zoom_in">+</div>
        
        <div class="mc-divider"></div>
        
        <div class="mc-btn" phx-click="zoom_out">−</div>
      </div>
      
      <div class="layers-fab" phx-click="open_layers_panel">⊞</div>
      
      <div class="compass" phx-click="reset_north">⊕</div>
      
    <!-- Pulse Legend -->
      <div class="pulse-legend">
        <div class="pl-title">Area pulse</div>
        
        <div class="pl-row">
          <div class="pl-dot" style="background: #f97316"></div>
          Buzzing
        </div>
        
        <div class="pl-row">
          <div class="pl-dot" style="background: #fbbf24"></div>
          Active
        </div>
        
        <div class="pl-row">
          <div class="pl-dot" style="background: #34d399"></div>
          Mellow
        </div>
        
        <div class="pl-row" style="margin: 0">
          <div class="pl-dot" style="background: #94a3b8"></div>
          Quiet
        </div>
      </div>
      
    <!-- Bottom Sheet -->
      <div
        id="vibeSheet"
        class="bottom-sheet"
        style={"transform: translateY(calc(100% - 200px))" <> if(@bottom_sheet_open, do: "; transform: translateY(0) !important", else: "")}
      >
        <div class="bs-handle" phx-click="toggle_bottom_sheet"></div>
        
        <div class="vibe-peek">
          <div>
            <div class="vibe-title" id="vibeTitle">
              {if @selected_place, do: @selected_place.name, else: "Nairobi CBD"}
            </div>
            
            <div class="vibe-sub">
              <span id="vibeArea">
                {if @selected_place, do: @selected_place.category, else: "Central Business District"}
              </span>
              
              <span class="pulse-badge">
                <span class="pulse-badge-dot"></span>
                <span id="vibePulse">
                  <%= if @selected_place && @selected_place.safety_score do %>
                    <%= if @selected_place.safety_score >= 80 do %>
                      Safe
                    <% else %>
                      Active now
                    <% end %>
                  <% else %>
                    Buzzing now
                  <% end %>
                </span>
              </span>
            </div>
          </div>
          
          <div class="vibe-actions">
            <div class="va-btn">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z"
                />
              </svg>
            </div>
            
            <div class="va-btn">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z"
                />
              </svg>
            </div>
            
            <div class="va-btn">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.217 10.907a2.25 2.25 0 100 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186l9.566-5.314m-9.566 7.5l9.566 5.314m0 0a2.25 2.25 0 103.935 2.186 2.25 2.25 0 00-3.935-2.186zm0-12.814a2.25 2.25 0 103.933-2.185 2.25 2.25 0 00-3.933 2.185z"
                />
              </svg>
            </div>
          </div>
        </div>
        
        <div class="quick-actions-row">
          <div class="qa-card">
            <div class="qa-icon">
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z"
                />
              </svg>
            </div>
            
            <div class="qa-label">Directions</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
                />
              </svg>
            </div>
            
            <div class="qa-label">What's on</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"
                />
              </svg>
            </div>
            
            <div class="qa-label">Get guide</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"
                />
              </svg>
            </div>
            
            <div class="qa-label">Photos</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
                />
              </svg>
            </div>
            
            <div class="qa-label">Reviews</div>
          </div>
        </div>
        
        <div class="section-row">
          <div class="sec-title">Signature sights</div>
          
          <div class="see-all">See all</div>
        </div>
        
        <div class="sight-scroll">
          <%= for place <- Enum.take(@places, 4) do %>
            <div class="sight-card" phx-click="place_selected" phx-value-place_id={place.id}>
              <div class="sight-img" style="background: #d1fae5">
                <%= case place.category do %>
                  <% "restaurant" -> %>
                    <svg
                      class="w-5 h-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.87c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513m-3-4.87v-1.5m-6 1.5v-1.5m12 9.75l-4.5-4.5M5.25 12l4.5 4.5m-4.5 0l4.5-4.5"
                      />
                    </svg>
                  <% "hotel" -> %>
                    <svg
                      class="w-5 h-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5M9 12h1.5M9 17.25h1.5M13.5 6.75h1.5M13.5 12h1.5M13.5 17.25h1.5"
                      />
                    </svg>
                  <% "attraction" -> %>
                    <svg
                      class="w-5 h-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456zM16.894 20.567L16.5 21.75l-.394-1.183a2.25 2.25 0 00-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 001.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 001.423 1.423l1.183.394-1.183.394a2.25 2.25 0 00-1.423 1.423z"
                      />
                    </svg>
                  <% "cafe" -> %>
                    <svg
                      class="w-5 h-5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M15.75 8.25V6a2.25 2.25 0 00-2.25-2.25h-6A2.25 2.25 0 005.25 6v2.25m10.5 0H18a2.25 2.25 0 012.25 2.25v2.25a2.25 2.25 0 01-2.25 2.25h-2.25m-10.5 0H6a2.25 2.25 0 01-2.25-2.25V10.5A2.25 2.25 0 016 8.25h2.25m10.5 0V18a2.25 2.25 0 01-2.25 2.25h-6A2.25 2.25 0 018.25 18v-2.25"
                      />
                    </svg>
                  <% _ -> %>
                    <svg
                      class="w-5 h-5 text-verdant-forest"
                      fill="currentColor"
                      stroke="none"
                      viewBox="0 0 24 24"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M11.54 22.351l.07.04.028.016a.76.76 0 00.723 0l.028-.015.071-.041a16.975 16.975 0 001.144-.742 19.58 19.58 0 002.683-2.282c1.944-1.99 3.963-4.98 3.963-8.827a8.25 8.25 0 00-16.5 0c0 3.846 2.02 6.837 3.963 8.827a19.58 19.58 0 002.682 2.282 16.975 16.975 0 001.145.742zM12 13.5a3 3 0 100-6 3 3 0 000 6z"
                        clip-rule="evenodd"
                      />
                    </svg>
                <% end %>
              </div>
              
              <div class="sight-info">
                <div class="sight-name">{place.name}</div>
                
                <div class="sight-meta">
                  ⭐ {if place.safety_score, do: place.safety_score / 10, else: 4.5} · {place.category}
                </div>
                
                <div class="sight-vibe">
                  <%= if place.safety_score && place.safety_score >= 70 do %>
                    🟢 Safe
                  <% else %>
                    🟡 Active
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
        <div class="section-row">
          <div class="sec-title">Active Mtaani guides</div>
          
          <div class="see-all">See all</div>
        </div>
        
        <div class="guide-scroll">
          <%= if Enum.empty?(@nearby_guides) do %>
            <div class="text-center text-gray-500 py-4 w-full">
              <p class="text-xs">No active guides nearby</p>
            </div>
          <% else %>
            <%= for guide <- @nearby_guides do %>
              <div
                class="guide-card"
                phx-click="navigate"
                phx-value-page={"profile/#{guide.username}"}
              >
                <div class="guide-av" style={"background: #{get_avatar_color(guide.id)}"}>
                  {guide.initials}
                </div>
                
                <div class="guide-info">
                  <div class="guide-name">{guide.name}</div>
                  
                  <div class="guide-area">{guide.area}</div>
                  
                  <div class="guide-status">
                    <%= if guide.availability_status == "online" do %>
                      ● Available now
                    <% else %>
                      ◐ Offline
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      
    <!-- Layers Panel -->
      <div
        id="layersPanel"
        class="layers-panel"
        style={
          if(@layers_panel_open, do: "transform: translateY(0)", else: "transform: translateY(100%)")
        }
      >
        <div class="bs-handle" style="cursor: default"></div>
        
        <div class="lp-header">
          <div class="lp-title">Map layers</div>
          
          <div class="lp-close" phx-click="close_layers_panel">✕</div>
        </div>
        
        <div class="lp-section">MAP STYLE</div>
        
        <div class="map-types">
          <div class="mt-card" phx-click="select_map_style" phx-value-style="explore">
            <div class={"mt-thumb explore " <> if(@map_style == "explore", do: "selected", else: "")}>
              🗺️
            </div>
            
            <div class="mt-label">Explore</div>
          </div>
          
          <div class="mt-card" phx-click="select_map_style" phx-value-style="transit">
            <div class={"mt-thumb transit " <> if(@map_style == "transit", do: "selected", else: "")}>
              🚌
            </div>
            
            <div class="mt-label">Transit</div>
          </div>
          
          <div class="mt-card" phx-click="select_map_style" phx-value-style="satellite">
            <div
              class={"mt-thumb satellite " <> if(@map_style == "satellite", do: "selected", else: "")}
              style="color: #fff; font-size: 18px"
            >
              🛰
            </div>
            
            <div class="mt-label">Satellite</div>
          </div>
          
          <div class="mt-card" phx-click="select_map_style" phx-value-style="terrain">
            <div class={"mt-thumb terrain " <> if(@map_style == "terrain", do: "selected", else: "")}>
              ⛰
            </div>
            
            <div class="mt-label">Terrain</div>
          </div>
          
          <div class="mt-card" phx-click="select_map_style" phx-value-style="night">
            <div
              class={"mt-thumb night " <> if(@map_style == "night", do: "selected", else: "")}
              style="font-size: 18px"
            >
              🌙
            </div>
            
            <div class="mt-label">Night</div>
          </div>
          
          <div class="mt-card" phx-click="select_map_style" phx-value-style="heatmap">
            <div class={"mt-thumb heatmap " <> if(@map_style == "heatmap", do: "selected", else: "")}>
              🌡
            </div>
            
            <div class="mt-label">Pulse map</div>
          </div>
        </div>
        
        <div class="lp-section" style="margin-top: 4px">MAP DETAILS</div>
        
        <div class="detail-grid">
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003.001 2.48z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 18a3.75 3.75 0 00.75-7.357 4.001 4.001 0 01-1.5 0A3.75 3.75 0 0012 18z"
                  />
                </svg>
              </span>
               <span class="dr-label">Pulse overlay</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.pulse, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="pulse"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4 text-green-500"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </span>
               <span class="dr-label">Verified spots</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.verified_spots, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="verified_spots"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"
                  />
                </svg>
              </span>
               <span class="dr-label">Guides online</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.guides_online, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="guides_online"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
                  />
                </svg>
              </span>
               <span class="dr-label">Events today</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.events_today, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="events_today"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4 text-verdant-forest"
                  fill="currentColor"
                  stroke="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    fill-rule="evenodd"
                    d="M11.54 22.351l.07.04.028.016a.76.76 0 00.723 0l.028-.015.071-.041a16.975 16.975 0 001.144-.742 19.58 19.58 0 002.683-2.282c1.944-1.99 3.963-4.98 3.963-8.827a8.25 8.25 0 00-16.5 0c0 3.846 2.02 6.837 3.963 8.827a19.58 19.58 0 002.682 2.282 16.975 16.975 0 001.145.742zM12 13.5a3 3 0 100-6 3 3 0 000 6z"
                    clip-rule="evenodd"
                  />
                </svg>
              </span>
               <span class="dr-label">Community pins</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.community_pins, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="community_pins"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.22-1.113-.615-1.53a15.014 15.014 0 00-6.135-3.256M6.75 13.5l.371 1.481A.75.75 0 007.835 15h4.33a.75.75 0 00.714-.519l.371-1.481"
                  />
                </svg>
              </span>
               <span class="dr-label">Matatu routes</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.matatu_routes, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="matatu_routes"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M2.25 15a4.5 4.5 0 004.5 4.5H18a3.75 3.75 0 001.332-7.257 3 3 0 00-3.758-3.848 5.25 5.25 0 00-10.233 2.33A4.502 4.502 0 002.25 15z"
                  />
                </svg>
              </span>
               <span class="dr-label">Weather layer</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.weather, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="weather"
            >
            </div>
          </div>
          
          <div class="detail-row">
            <div class="dr-left">
              <span class="dr-icon">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.045.58.02 1.193-.14 1.743"
                  />
                </svg>
              </span>
               <span class="dr-label">Road works</span>
            </div>
            
            <div
              class={"toggle " <> if(@map_layers.road_works, do: "on", else: "")}
              phx-click="toggle_layer"
              phx-value-layer="road_works"
            >
            </div>
          </div>
        </div>
      </div>
      
    <!-- Bottom Navigation -->
      <div class="absolute bottom-0 left-0 right-0 z-20">
        <BottomNav.bottom_nav active="map" />
      </div>
    </div>
    """
  end
end
