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

    {:ok, socket}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_event("user_location_update", %{"lat" => lat, "lng" => lng}, socket) do
    socket = assign(socket, :user_location, %{lat: lat, lng: lng})
    {:noreply, socket |> load_nearby_places(lat, lng) |> load_activity_zones(lat, lng)}
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
            <span class="s-icon">🔍</span>
            <input
              type="text"
              id="searchInput"
              placeholder="Search Nairobi, East Africa..."
              phx-keyup="search"
              phx-debounce="300"
              value={@search_query}
            /> <span class="s-mic">🎙</span>
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
            <span class="tab-icon">🏠</span> Set home
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="restaurant"
            class={get_tab_class(@current_filter, "restaurant")}
          >
            <span class="tab-icon">🍽</span> Eat
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="hotel"
            class={get_tab_class(@current_filter, "hotel")}
          >
            <span class="tab-icon">🏨</span> Stay
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="attraction"
            class={get_tab_class(@current_filter, "attraction")}
          >
            <span class="tab-icon">✨</span> Explore
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="cafe"
            class={get_tab_class(@current_filter, "cafe")}
          >
            <span class="tab-icon">☕</span> Coffee
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="fuel"
            class={get_tab_class(@current_filter, "fuel")}
          >
            <span class="tab-icon">⛽</span> Fuel
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="matatu"
            class={get_tab_class(@current_filter, "matatu")}
          >
            <span class="tab-icon">🚐</span> Matatu
          </button>
          
          <button
            phx-click="filter_places_by_category"
            phx-value-category="health"
            class={get_tab_class(@current_filter, "health")}
          >
            <span class="tab-icon">🏥</span> Health
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
            <div class="va-btn">🧭</div>
            
            <div class="va-btn">🔖</div>
            
            <div class="va-btn">📤</div>
          </div>
        </div>
        
        <div class="quick-actions-row">
          <div class="qa-card">
            <div class="qa-icon">🧭</div>
            
            <div class="qa-label">Directions</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">🗓</div>
            
            <div class="qa-label">What's on</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">🙋</div>
            
            <div class="qa-label">Get guide</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">📸</div>
            
            <div class="qa-label">Photos</div>
          </div>
          
          <div class="qa-card">
            <div class="qa-icon">💬</div>
            
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
                {case place.category do
                  "restaurant" -> "🍽️"
                  "hotel" -> "🏨"
                  "attraction" -> "✨"
                  "cafe" -> "☕"
                  _ -> "📍"
                end}
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
          <div class="guide-card">
            <div class="guide-av" style="background: #10b981">NB</div>
            
            <div class="guide-info">
              <div class="guide-name">Njoroge B.</div>
              
              <div class="guide-area">CBD · Karen · Ngong</div>
              
              <div class="guide-status">● Available now</div>
            </div>
          </div>
          
          <div class="guide-card">
            <div class="guide-av" style="background: #3b82f6">WN</div>
            
            <div class="guide-info">
              <div class="guide-name">Wanjiru N.</div>
              
              <div class="guide-area">Westlands · Parklands</div>
              
              <div class="guide-status">● Available now</div>
            </div>
          </div>
          
          <div class="guide-card">
            <div class="guide-av" style="background: #8b5cf6">KO</div>
            
            <div class="guide-info">
              <div class="guide-name">Kofi A.</div>
              
              <div class="guide-area">Kilimani · Lavington</div>
              
              <div class="guide-status" style="color: #f59e0b">◐ In 2 hrs</div>
            </div>
          </div>
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
              <span class="dr-icon">🔥</span><span class="dr-label">Pulse overlay</span>
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
              <span class="dr-icon">✅</span><span class="dr-label">Verified spots</span>
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
              <span class="dr-icon">🙋</span><span class="dr-label">Guides online</span>
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
              <span class="dr-icon">🎉</span><span class="dr-label">Events today</span>
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
              <span class="dr-icon">📍</span><span class="dr-label">Community pins</span>
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
              <span class="dr-icon">🚌</span><span class="dr-label">Matatu routes</span>
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
              <span class="dr-icon">🌦</span><span class="dr-label">Weather layer</span>
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
              <span class="dr-icon">🚧</span><span class="dr-label">Road works</span>
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
      <div class="nav-bar">
        <div class="nav-item" phx-click="navigate" phx-value-page="home">
          <div class="nav-icon">🏠</div>
          
          <div class="nav-label">Home</div>
        </div>
        
        <div class="nav-item active" phx-click="navigate" phx-value-page="map">
          <div class="nav-icon">🗺️</div>
          
          <div class="nav-label" style="color: #10b981; font-weight: 500">Map</div>
        </div>
        
        <div class="nav-item" phx-click="navigate" phx-value-page="chat">
          <div class="nav-icon">💬</div>
          
          <div class="nav-label">Chat</div>
        </div>
        
        <div class="nav-item" phx-click="navigate" phx-value-page="groups">
          <div class="nav-icon">👥</div>
          
          <div class="nav-label">Groups</div>
        </div>
        
        <div class="nav-item" phx-click="navigate" phx-value-page="plan">
          <div class="nav-icon">🗓</div>
          
          <div class="nav-label">Plan</div>
        </div>
      </div>
    </div>
    """
  end
end
