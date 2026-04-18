defmodule MtaaniWeb.WelcomeLive do
  use MtaaniWeb, :live_view

  alias Mtaani.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if is_nil(user_id) do
      {:ok, push_navigate(socket, to: "/")}
    else
      current_user = Mtaani.Repo.get(User, user_id)

      if is_nil(current_user) do
        {:ok, push_navigate(socket, to: "/")}
      else
        traveler_type = current_user.preferences["traveler_type"] || "traveler"

        type_display =
          case traveler_type do
            "traveler" -> "Traveler"
            "guide" -> "Local guide"
            "resident" -> "Local resident"
            "business" -> "Business"
            _ -> "Traveler"
          end

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:avatar_initials, get_initials(current_user.name))
         |> assign(:avatar_color, get_avatar_color(current_user.id))
         |> assign(:type_badge, type_display)
         |> assign(:show_emergency, false)}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20">
      <div class="max-w-md mx-auto px-4 py-12">
        <!-- Success Icon -->
        <div class="flex justify-center mb-6">
          <div class="w-20 h-20 rounded-full bg-green-50 border-2 border-green-200 flex items-center justify-center animate-bounce">
            <svg
              class="w-10 h-10 text-green-500"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
          </div>
        </div>
        
    <!-- Title -->
        <div class="text-center mb-4">
          <h1 class="text-2xl font-semibold text-onyx-deep">You're in, {@current_user.name}!</h1>
          
          <p class="text-sm text-onyx-mauve mt-2">
            Your Mtaani account is ready. Kenya is waiting for you.
          </p>
        </div>
        
    <!-- User Preview Card -->
        <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-onyx-mauve/20 p-4 flex items-center gap-3 mb-6">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center text-lg font-semibold text-white shadow-sm"
            style={"background: #{@avatar_color}"}
          >
            {@avatar_initials}
          </div>
          
          <div class="flex-1">
            <div class="font-medium text-onyx-deep">{@current_user.name}</div>
            
            <div class="text-xs text-onyx-mauve">@{@current_user.username} · Nairobi, Kenya</div>
            
            <div class="flex gap-2 mt-1">
              <span class="text-xs px-2 py-0.5 rounded-full bg-green-50 text-green-700">
                Verified member
              </span>
              
              <span class="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                {@type_badge}
              </span>
            </div>
          </div>
        </div>
        
    <!-- Action Cards -->
        <div class="grid grid-cols-2 gap-3 mb-6">
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-onyx-mauve/20 p-3">
            <div class="w-8 h-8 rounded-lg bg-green-50 flex items-center justify-center mb-2">
              <svg
                class="w-4 h-4 text-green-600"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                
                <circle cx="9" cy="7" r="4"></circle>
                
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
            </div>
            
            <div class="text-sm font-medium text-onyx-deep">Find your people</div>
            
            <div class="text-xs text-onyx-mauve mt-1">Connect with guides and travelers near you</div>
          </div>
          
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-onyx-mauve/20 p-3">
            <div class="w-8 h-8 rounded-lg bg-green-50 flex items-center justify-center mb-2">
              <svg
                class="w-4 h-4 text-green-600"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
                
                <circle cx="12" cy="10" r="3"></circle>
              </svg>
            </div>
            
            <div class="text-sm font-medium text-onyx-deep">Explore the map</div>
            
            <div class="text-xs text-onyx-mauve mt-1">47 counties, 18K+ mapped places</div>
          </div>
        </div>
        
    <!-- Action Buttons -->
        <button
          phx-click="start_exploring"
          class="w-full bg-verdant-forest text-white py-3 rounded-xl font-medium hover:bg-verdant-deep transition-all shadow-lg"
        >
          Start exploring Kenya
        </button>
        
        <div class="text-center mt-4">
          <button
            phx-click="complete_profile_later"
            class="text-sm text-onyx-mauve hover:text-verdant-forest transition-colors"
          >
            Complete your profile first
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("start_exploring", _, socket) do
    {:noreply, push_navigate(socket, to: "/home")}
  end

  @impl true
  def handle_event("complete_profile_later", _, socket) do
    {:noreply, push_navigate(socket, to: "/profile-setup")}
  end

  @impl true
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end

  def handle_event("user_online", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.add_user(user_id)
    {:noreply, socket}
  end

  def handle_event("user_offline", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.remove_user(user_id)
    {:noreply, socket}
  end

  defp get_initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  defp get_avatar_color(user_id) do
    colors = ["#10b981", "#3b82f6", "#8b5cf6", "#f59e0b", "#e11d48", "#0891b2", "#6366f1"]
    index = rem(user_id, length(colors))
    Enum.at(colors, index)
  end
end
