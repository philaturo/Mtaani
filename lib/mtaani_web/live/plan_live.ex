defmodule MtaaniWeb.PlanLive do
  use MtaaniWeb, :live_view
  alias Mtaani.Plan
  alias Mtaani.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Get user from session
    current_user =
      case session do
        %{"user_id" => user_id} -> Accounts.get_user(user_id)
        _ -> nil
      end

    if is_nil(current_user) do
      # No user found, redirect to login
      {:ok, push_navigate(socket, to: "/login")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "trips:#{current_user.id}")
      end

      # Load initial data
      trips = Plan.list_user_trips(current_user.id)
      # destinations = Plan.get_popular_destinations(10)
      guides = Plan.get_recommended_guides(8)
      # activities = Plan.search_activities("", 10)
      # Temporarily disable activities : Temporarily empty - remove when Geo is fixed
      activities = []

      # Group trips by status
      {upcoming_trips, other_trips} = Enum.split_with(trips, &(&1.status == "upcoming"))
      {active_trips, planning_trips} = Enum.split_with(other_trips, &(&1.status == "active"))
      completed_trips = Enum.filter(trips, &(&1.status == "completed"))

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:active_tab, "plan")
        |> assign(:trips, trips)
        |> assign(:upcoming_trips, upcoming_trips)
        |> assign(:active_trips, active_trips)
        |> assign(:planning_trips, planning_trips)
        |> assign(:completed_trips, completed_trips)
        #  |> assign(:destinations, destinations)
        |> assign(:destinations, [])
        |> assign(:guides, guides)
        # |> assign(:activities, activities)
        # Empty for now
        |> assign(:activities, [])
        |> assign(:selected_type_tab, "trips")
        |> assign(:show_create_modal, false)
        |> assign(:new_trip_name, "")
        |> assign(:selected_destination, nil)
        |> assign(:new_trip_start_date, nil)
        |> assign(:new_trip_end_date, nil)
        |> assign(:traveler_count, 2)
        |> assign(:new_trip_budget, nil)
        |> assign(:selected_vibes, [])

      {:ok, socket}
    end
  end

  # ==================== HANDLE INFO FUNCTIONS ====================

  @impl true
  def handle_info({:trip_created, _trip}, socket) do
    trips = Plan.list_user_trips(socket.assigns.current_user.id)
    {:noreply, assign(socket, trips: trips, show_create_modal: false)}
  end

  @impl true
  def handle_info({:trip_updated, _trip}, socket) do
    trips = Plan.list_user_trips(socket.assigns.current_user.id)
    {:noreply, assign(socket, trips: trips)}
  end

  # ==================== HANDLE EVENT FUNCTIONS ====================

  # Tab switching
  @impl true
  def handle_event("switch_type_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user

    socket =
      case tab do
        "trips" -> assign(socket, trips: Plan.list_user_trips(current_user.id))
        "activities" -> assign(socket, activities: Plan.search_activities("", 20))
        "guides" -> assign(socket, guides: Plan.get_recommended_guides(12))
        _ -> socket
      end

    {:noreply, assign(socket, selected_type_tab: tab)}
  end

  # Create Trip Modal
  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: true)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false)}
  end

  @impl true
  def handle_event("update_trip_field", %{"field" => "name", "value" => value}, socket) do
    {:noreply, assign(socket, new_trip_name: value)}
  end

  @impl true
  def handle_event("update_trip_field", %{"field" => "budget", "value" => value}, socket) do
    budget =
      case Integer.parse(value) do
        {num, ""} -> num
        _ -> nil
      end

    {:noreply, assign(socket, new_trip_budget: budget)}
  end

  @impl true
  def handle_event("update_destination", %{"destination" => dest}, socket) do
    {:noreply, assign(socket, selected_destination: dest)}
  end

  @impl true
  def handle_event("update_travelers", %{"delta" => delta}, socket) do
    new_count = max(1, socket.assigns.traveler_count + String.to_integer(delta))
    {:noreply, assign(socket, traveler_count: new_count)}
  end

  @impl true
  def handle_event("toggle_vibe", %{"vibe" => vibe}, socket) do
    vibes = socket.assigns.selected_vibes
    new_vibes = if vibe in vibes, do: List.delete(vibes, vibe), else: [vibe | vibes]
    {:noreply, assign(socket, selected_vibes: new_vibes)}
  end

  @impl true
  def handle_event("set_start_date", %{"date" => date}, socket) do
    {:noreply, assign(socket, new_trip_start_date: date)}
  end

  @impl true
  def handle_event("set_end_date", %{"date" => date}, socket) do
    {:noreply, assign(socket, new_trip_end_date: date)}
  end

  @impl true
  def handle_event("create_trip", _params, socket) do
    current_user = socket.assigns.current_user

    attrs = %{
      "name" => socket.assigns.new_trip_name,
      "destination" => socket.assigns.selected_destination,
      "start_date" => socket.assigns.new_trip_start_date,
      "end_date" => socket.assigns.new_trip_end_date,
      "budget_per_person" => socket.assigns.new_trip_budget,
      "vibe_tags" => socket.assigns.selected_vibes,
      "status" => "planning"
    }

    case Plan.create_trip(attrs, current_user.id) do
      {:ok, trip} ->
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "trips:#{current_user.id}", {:trip_created, trip})

        {:noreply,
         socket
         |> assign(show_create_modal: false)
         |> put_flash(:info, "Trip created successfully!")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create trip: #{inspect(changeset.errors)}")}
    end
  end

  # AI Trip Builder
  @impl true
  def handle_event("ai_build_trip", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "AI trip builder coming soon! Tell us your preferences and we'll build the perfect itinerary."
     )}
  end

  # View Trip Detail
  @impl true
  def handle_event("view_trip", %{"id" => trip_id}, socket) do
    {:noreply, push_navigate(socket, to: "/trip/#{trip_id}")}
  end

  # Navigation
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("search", _params, socket) do
    # Open search modal or navigate to search page
    {:noreply, put_flash(socket, :info, "Search feature coming soon!")}
  end

  # ==================== RENDER FUNCTION ====================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="plan-page-wrapper">
      <div class="plan-container">
        <!-- Plan Page Top Bar -->
        <div class="plan-top-bar">
          <h1 class="plan-title">Plan</h1>
          
          <div class="plan-actions">
            <button class="plan-icon-btn" phx-click="search">
              🔍
            </button>
            
            <button class="plan-icon-btn" phx-click="open_create_modal">
              ＋
            </button>
            
            <button class="plan-icon-btn" phx-click="navigate" phx-value-page="profile">
              👤
            </button>
          </div>
        </div>
        
        <.hero_section
          current_user={@current_user}
          selected_destination={@selected_destination}
          new_trip_start_date={@new_trip_start_date}
          new_trip_end_date={@new_trip_end_date}
          traveler_count={@traveler_count}
          open_create_modal="open_create_modal"
        /> <.type_tabs selected={@selected_type_tab} switch_tab="switch_type_tab" />
        <.ai_strip ai_build_trip="ai_build_trip" />
        <%= if @selected_type_tab == "trips" do %>
          <.my_trips_section
            upcoming_trips={@upcoming_trips}
            active_trips={@active_trips}
            planning_trips={@planning_trips}
            completed_trips={@completed_trips}
            view_trip="view_trip"
          />
        <% end %>
         <.discover_kenya destinations={@destinations} /> <.local_guides guides={@guides} />
        <.activities_section activities={@activities} />
        <%= if @show_create_modal do %>
          <.create_trip_modal
            new_trip_name={@new_trip_name}
            selected_destination={@selected_destination}
            new_trip_start_date={@new_trip_start_date}
            new_trip_end_date={@new_trip_end_date}
            traveler_count={@traveler_count}
            new_trip_budget={@new_trip_budget}
            selected_vibes={@selected_vibes}
            update_trip_field="update_trip_field"
            update_destination="update_destination"
            update_travelers="update_travelers"
            toggle_vibe="toggle_vibe"
            set_start_date="set_start_date"
            set_end_date="set_end_date"
            create_trip="create_trip"
            ai_build_trip="ai_build_trip"
            close_create_modal="close_create_modal"
          />
        <% end %>
      </div>
    </div>
    """
  end

  # Component Functions (defined within the module)

  def hero_section(assigns) do
    ~H"""
    <div class="hero">
      <div class="hero-pattern"></div>
      
      <div class="hero-greeting">Habari {@current_user.name || "Traveler"} 👋</div>
      
      <div class="hero-title">Where is Kenya<br />taking you next?</div>
      
      <div class="hero-search">
        <div class="hs-row" phx-click={@open_create_modal}>
          <span class="hs-icon">📍</span>
          <div class="hs-text">
            <div class="hs-label">DESTINATION</div>
            
            <div class="hs-val">
              <%= if @selected_destination do %>
                {@selected_destination}
              <% else %>
                Anywhere in Kenya
              <% end %>
            </div>
          </div>
        </div>
        
        <div class="hs-divider"></div>
        
        <div class="hs-bottom">
          <div class="hs-cell" phx-click={@open_create_modal}>
            <div class="hs-cell-label">CHECK IN</div>
            
            <div class="hs-cell-val">
              <%= if @new_trip_start_date do %>
                {@new_trip_start_date}
              <% else %>
                Pick date
              <% end %>
            </div>
          </div>
          
          <div class="hs-sep"></div>
          
          <div class="hs-cell" phx-click={@open_create_modal}>
            <div class="hs-cell-label">CHECK OUT</div>
            
            <div class="hs-cell-val">
              <%= if @new_trip_end_date do %>
                {@new_trip_end_date}
              <% else %>
                Pick date
              <% end %>
            </div>
          </div>
          
          <div class="hs-sep"></div>
          
          <div class="hs-cell" phx-click={@open_create_modal}>
            <div class="hs-cell-label">TRAVELERS</div>
            
            <div class="hs-cell-val">
              {@traveler_count} {if @traveler_count == 1, do: "person", else: "people"}
            </div>
          </div>
        </div>
         <button class="search-btn" phx-click={@open_create_modal}>Search & plan with AI ✦</button>
      </div>
    </div>
    """
  end

  def type_tabs(assigns) do
    ~H"""
    <div class="type-tabs">
      <button
        class={"ttab #{if @selected == "trips", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="trips"
      >
        🗺 Trips
      </button>
      
      <button
        class={"ttab #{if @selected == "flights", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="flights"
      >
        ✈️ Flights
      </button>
      
      <button
        class={"ttab #{if @selected == "hotels", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="hotels"
      >
        🏨 Hotels
      </button>
      
      <button
        class={"ttab #{if @selected == "activities", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="activities"
      >
        🎭 Activities
      </button>
      
      <button
        class={"ttab #{if @selected == "transport", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="transport"
      >
        🚐 Transport
      </button>
      
      <button
        class={"ttab #{if @selected == "guides", do: "on"}"}
        phx-click={@switch_tab}
        phx-value-tab="guides"
      >
        🧭 Guides
      </button>
    </div>
    """
  end

  def ai_strip(assigns) do
    ~H"""
    <div class="ai-strip" phx-click={@ai_build_trip}>
      <div class="ai-icon">✦</div>
      
      <div class="ai-body">
        <div class="ai-title">AI trip builder — Kenya edition</div>
        
        <div class="ai-sub">
          Tell us your vibe — beach, safari, mountain, city — and we'll build a full itinerary, find guides, and split your budget automatically.
        </div>
        
        <div class="ai-action">Build my trip →</div>
      </div>
    </div>
    """
  end

  def my_trips_section(assigns) do
    ~H"""
    <div class="sec">MY TRIPS <span class="see-all">See all</span></div>

    <%= if Enum.empty?(@upcoming_trips) and Enum.empty?(@active_trips) and Enum.empty?(@planning_trips) do %>
      <div class="text-center py-8 px-4">
        <div class="w-16 h-16 rounded-full bg-onyx-mauve/10 flex items-center justify-center mx-auto mb-4">
          <span class="text-2xl">✈️</span>
        </div>
        
        <p class="text-onyx-deep">No trips planned yet</p>
        
        <p class="text-sm text-onyx-mauve mt-1">Start planning your next adventure</p>
      </div>
    <% else %>
      <%= if !Enum.empty?(@upcoming_trips) do %>
        <div class="sec-sub">Upcoming</div>
        
        <%= for trip <- @upcoming_trips do %>
          <.trip_card trip={trip} status="upcoming" view_trip={@view_trip} />
        <% end %>
      <% end %>
      
      <%= if !Enum.empty?(@active_trips) do %>
        <div class="sec-sub">Active</div>
        
        <%= for trip <- @active_trips do %>
          <.trip_card trip={trip} status="active" view_trip={@view_trip} />
        <% end %>
      <% end %>
      
      <%= if !Enum.empty?(@planning_trips) do %>
        <div class="sec-sub">Planning</div>
        
        <%= for trip <- @planning_trips do %>
          <.trip_card trip={trip} status="planning" view_trip={@view_trip} />
        <% end %>
      <% end %>
    <% end %>
    """
  end

  def trip_card(assigns) do
    ~H"""
    <div class="trip-card" phx-click={@view_trip} phx-value-id={@trip.id}>
      <div class="tc-cover" style={"background: #{status_color(@status)}"}>
        {@trip.cover_emoji}
        <div class={"tc-status #{status_class(@status)}"}>
          {status_text(@status)} · {format_date_short(@trip.start_date)}
        </div>
        
        <div class="tc-collab">
          <%= for participant <- Enum.take(@trip.participants || [], 4) do %>
            <div class="tc-av" style={"background: #{avatar_color(participant.user_id)}"}>
              {initials(participant.user.name)}
            </div>
          <% end %>
          
          <%= if length(@trip.participants || []) > 4 do %>
            <div class="tc-av" style="background: #f59e0b">+{length(@trip.participants) - 4}</div>
          <% end %>
        </div>
      </div>
      
      <div class="tc-body">
        <div class="tc-name">{@trip.name}</div>
        
        <div class="tc-meta">
          <span>📍 {@trip.destination}</span>
          <span>
            {Date.diff(@trip.end_date, @trip.start_date)} days · {length(@trip.participants || [])} people
          </span>
        </div>
        
        <div class="tc-progress">
          <div class="tc-bar" style={"width: #{@trip.progress_percentage}%"}></div>
        </div>
        
        <div class="tc-footer">
          <span
            class="tc-tag"
            style={"background: #{progress_color(@trip.progress_percentage)}; color: #{progress_text_color(@trip.progress_percentage)}"}
          >
            {@trip.progress_percentage}% planned
          </span>
          
          <span class="budget-chip">
            KSh {format_number(@trip.budget_per_person || 0)} / person
          </span>
        </div>
      </div>
    </div>
    """
  end

  def discover_kenya(assigns) do
    ~H"""
    <div class="sec">DISCOVER KENYA <span class="see-all">See all</span></div>

    <div class="dest-scroll">
      <%= for destination <- @destinations do %>
        <div class="dest-card">
          <div class="dc-img" style={"background: #{destination_color(destination)}"}>
            {destination_emoji(destination)}
            <div class="dc-vibe" style="background: #ecfdf5; color: #065f46">
              🔥 Popular
            </div>
          </div>
          
          <div class="dc-body">
            <div class="dc-name">{destination.name}</div>
            
            <div class="dc-meta">
              ⭐ {Float.round(destination.safety_score || 4.5, 1)} · {destination.category ||
                "Destination"} · {destination.address || "Kenya"}
            </div>
            
            <div class="dc-price">
              From KSh {destination.price_range || "8,000"}/night
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def local_guides(assigns) do
    ~H"""
    <div class="sec">LOCAL EXPERT GUIDES <span class="see-all">Browse all</span></div>

    <div class="guide-scroll">
      <%= for guide <- @guides do %>
        <div class="guide-card">
          <div class="gc-av" style={"background: #{guide_color(guide)}"}>
            {initials(guide.user.name)}
            <div class="gc-online"></div>
          </div>
          
          <div class="gc-name">{guide.user.name}</div>
          
          <div class="gc-area">
            {guide.user.location || "Nairobi"} · {guide.user.traveler_type || "Expert"}
          </div>
          
          <div class="gc-rating">★ {Float.round(guide.rating, 2)} · {guide.total_tours} trips</div>
          
          <div class="gc-badge">
            {if guide.verification_status == "verified", do: "✅ Verified", else: "⭐ Top rated"}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def activities_section(assigns) do
    ~H"""
    <div class="sec">ACTIVITIES & EXPERIENCES <span class="see-all">See all</span></div>

    <div class="act-scroll">
      <%= for activity <- @activities do %>
        <div class="act-card">
          <div class="ac-img" style={"background: #{activity_color(activity)}"}>
            {activity_emoji(activity)}
          </div>
          
          <div class="ac-body">
            <div class="ac-name">{activity.name}</div>
            
            <div class="ac-guide">
              <div class="ac-av" style="background: #e11d48">NB</div>
               <span class="ac-gname">Local experience</span>
            </div>
            
            <div class="ac-footer">
              <span class="ac-price">KSh {activity.price_range || "3,500"}/person</span>
              <span class="ac-rating">★ {Float.round(activity.safety_score || 4.5, 1)}</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def create_trip_modal(assigns) do
    ~H"""
    <div class="modal-bg open" phx-click={@close_create_modal}>
      <div class="modal-sheet" phx-click-away={@close_create_modal}>
        <div class="msh"></div>
        
        <div class="ms-title">Plan a new trip ✦</div>
        
        <div class="ms-body">
          <div class="ms-label">Trip name</div>
          
          <input
            class="ms-input"
            placeholder="e.g., Mara Safari Weekend"
            value={@new_trip_name}
            phx-blur={@update_trip_field}
            phx-value-field="name"
          />
          <div class="ms-label">Choose destination</div>
          
          <div class="dest-option-grid">
            <button
              class={"dest-opt #{if @selected_destination == "Maasai Mara", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Maasai Mara"
            >
              <div class="do-emoji">🦁</div>
              
              <div class="do-name">Maasai Mara</div>
            </button>
            
            <button
              class={"dest-opt #{if @selected_destination == "Diani Beach", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Diani Beach"
            >
              <div class="do-emoji">🏖</div>
              
              <div class="do-name">Diani Beach</div>
            </button>
            
            <button
              class={"dest-opt #{if @selected_destination == "Mt. Kenya", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Mt. Kenya"
            >
              <div class="do-emoji">🏔</div>
              
              <div class="do-name">Mt. Kenya</div>
            </button>
            
            <button
              class={"dest-opt #{if @selected_destination == "Lamu Island", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Lamu Island"
            >
              <div class="do-emoji">🏝</div>
              
              <div class="do-name">Lamu Island</div>
            </button>
            
            <button
              class={"dest-opt #{if @selected_destination == "Amboseli", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Amboseli"
            >
              <div class="do-emoji">🌋</div>
              
              <div class="do-name">Amboseli</div>
            </button>
            
            <button
              class={"dest-opt #{if @selected_destination == "Other", do: "sel"}"}
              phx-click={@update_destination}
              phx-value-destination="Other"
            >
              <div class="do-emoji">📍</div>
              
              <div class="do-name">Other</div>
            </button>
          </div>
          
          <div class="ms-label">Dates</div>
          
          <div class="date-row">
            <input type="date" class="date-box" phx-change={@set_start_date} />
            <input type="date" class="date-box" phx-change={@set_end_date} />
          </div>
          
          <div class="ms-label">Travelers</div>
          
          <div class="traveler-row">
            <div class="tr-label">Number of people</div>
            
            <div class="tr-counter">
              <button class="tc-minus" phx-click={@update_travelers} phx-value-delta="-1">−</button>
              <div class="tc-num">{@traveler_count}</div>
               <button class="tc-plus" phx-click={@update_travelers} phx-value-delta="1">＋</button>
            </div>
          </div>
          
          <div class="ms-label">Budget per person</div>
          
          <input
            class="ms-input"
            type="number"
            placeholder="e.g., 35000"
            value={@new_trip_budget}
            phx-blur={@update_trip_field}
            phx-value-field="budget"
          />
          <div class="ms-label">Trip vibe</div>
          
          <div class="vibe-opts">
            <%= for vibe <- ["🦁 Safari", "🥾 Hiking", "🏖 Beach", "🏙 City", "🌿 Nature", "🎭 Culture", "🍽 Food", "🎉 Festival"] do %>
              <button
                class={"vo #{if vibe in @selected_vibes, do: "sel"}"}
                phx-click={@toggle_vibe}
                phx-value-vibe={vibe}
              >
                {vibe}
              </button>
            <% end %>
          </div>
          
          <button class="ai-suggest-btn" phx-click={@ai_build_trip}>
            ✦ Build AI itinerary for this trip
          </button>
           <button class="create-btn" phx-click={@create_trip}>Create trip & invite group</button>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions for styling
  defp status_color("upcoming"), do: "#d1fae5"
  defp status_color("active"), do: "#fef3c7"
  defp status_color("planning"), do: "#e0f2fe"
  defp status_color(_), do: "#f8fafc"

  defp status_class("upcoming"), do: "ts-upcoming"
  defp status_class("active"), do: "ts-active"
  defp status_class("planning"), do: "ts-planning"
  defp status_class(_), do: "ts-completed"

  defp status_text("upcoming"), do: "Upcoming"
  defp status_text("active"), do: "Active"
  defp status_text("planning"), do: "Planning"
  defp status_text(_), do: "Completed"

  defp progress_color(progress) when progress >= 75, do: "#ecfdf5"
  defp progress_color(progress) when progress >= 50, do: "#eff6ff"
  defp progress_color(_), do: "#fff7ed"

  defp progress_text_color(progress) when progress >= 75, do: "#065f46"
  defp progress_text_color(progress) when progress >= 50, do: "#1e40af"
  defp progress_text_color(_), do: "#c2410c"

  defp format_date_short(date) do
    Calendar.strftime(date, "%b %d")
  end

  defp format_number(nil), do: "0"
  defp format_number(num), do: Number.delimit(num)

  defp initials(nil), do: "??"

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp avatar_color(user_id) do
    colors = ["#e11d48", "#3b82f6", "#8b5cf6", "#f59e0b", "#10b981", "#6366f1"]
    Enum.at(colors, rem(user_id, length(colors)))
  end

  defp destination_color(destination) do
    cond do
      String.contains?(destination.name, "Mara") -> "#d1fae5"
      String.contains?(destination.name, "Beach") -> "#e0f2fe"
      String.contains?(destination.name, "Mountain") -> "#fef3c7"
      true -> "#fce7f3"
    end
  end

  defp destination_emoji(destination) do
    cond do
      String.contains?(destination.name, "Mara") -> "🦁"
      String.contains?(destination.name, "Beach") -> "🏖"
      String.contains?(destination.name, "Mountain") -> "🏔"
      true -> "📍"
    end
  end

  defp guide_color(guide) do
    colors = ["#e11d48", "#3b82f6", "#8b5cf6", "#f59e0b"]
    Enum.at(colors, rem(guide.id, length(colors)))
  end

  defp activity_color(activity) do
    cond do
      activity.category == "safari" -> "#d1fae5"
      activity.category == "beach" -> "#e0f2fe"
      activity.category == "hiking" -> "#fef3c7"
      true -> "#fce7f3"
    end
  end

  defp activity_emoji(activity) do
    cond do
      activity.category == "safari" -> "🦁"
      activity.category == "beach" -> "🏖"
      activity.category == "hiking" -> "🏔"
      true -> "🎭"
    end
  end
end
