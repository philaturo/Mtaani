defmodule MtaaniWeb.HomeLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = %{name: "Explorer"}
    
    socket =
      socket
      |> assign(:active_tab, "home")
      |> assign(:show_emergency, false)
      |> assign(:user, user)
      |> assign(:messages, [])
      |> assign(:input_text, "")
      |> assign(:thinking, false)
      |> assign(:user_location, nil)
      |> assign(:current_vibe, :unknown)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
      send(self(), :request_location)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:request_location, socket) do
    {:noreply, push_event(socket, "request-geolocation", %{})}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_info({:ai_response, user_message}, socket) do
    response = """
    I understand you're asking about "#{user_message}". 
    With your current location, I can help you find local spots, 
    check safety conditions, or give you directions.
    """
    messages = socket.assigns.messages ++ [%{role: :assistant, content: response, timestamp: DateTime.utc_now()}]
    {:noreply, assign(socket, [messages: messages, thinking: false])}
  end

  # ==================== ALL handle_event/3 FUNCTIONS ====================
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("location-update", %{"lat" => lat, "lng" => lng}, socket) do
    {:noreply,
     socket
     |> assign(:user_location, %{lat: lat, lng: lng})
     |> assign(:current_vibe, :calm)}
  end

  @impl true
  def handle_event("location-error", %{"error" => error}, socket) do
    IO.puts("Geolocation error: #{error}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("location-moved", %{"lat" => lat, "lng" => lng}, socket) do
    {:noreply, assign(socket, :user_location, %{lat: lat, lng: lng})}
  end

  @impl true
  def handle_event("update-input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_text, message)}
  end

  @impl true
  def handle_event("send-message", %{"message" => message}, socket) when message != "" do
    messages = socket.assigns.messages ++ [%{role: :user, content: message, timestamp: DateTime.utc_now()}]
    socket = assign(socket, [messages: messages, thinking: true, input_text: ""])
    send(self(), {:ai_response, message})
    {:noreply, socket}
  end

  @impl true
  def handle_event("send-message", _, socket), do: {:noreply, socket}

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
  
    # Emergency Modal Handlers
  @impl true
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end

  @impl true
  def handle_event("call_police", _, socket) do
    {:noreply, push_event(socket, "call_number", %{number: "999"})}
  end

  @impl true
  def handle_event("call_ambulance", _, socket) do
    {:noreply, push_event(socket, "call_number", %{number: "911"})}
  end

  @impl true
  def handle_event("call_contact", %{"phone" => phone}, socket) do
    {:noreply, push_event(socket, "call_number", %{number: phone})}
  end

  @impl true
  def handle_event("share_location", _, socket) do
    {:noreply, push_event(socket, "share_location", %{})}
  end

  @impl true
  def handle_event("sos_alert", _, socket) do
    {:noreply, push_event(socket, "sos_alert", %{})}
  end

  @impl true
  def handle_event("trigger_emergency", _, socket) do
    {:noreply, push_event(socket, "trigger_emergency", %{})}
  end
  
  # ==================== END handle_event/3 FUNCTIONS ====================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col max-w-3xl mx-auto px-4 py-6 pb-20">
      <!-- Welcome Header -->
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-onyx-deep">Welcome back, <%= @user.name %></h1>
        <p class="text-onyx-mauve mt-1">Your intelligent guide to Nairobi</p>
      </div>

      <!-- Feature Cards Grid -->
      <div class="grid grid-cols-2 gap-4 mb-8">
        <button phx-click="send-message" phx-value-message="Find local food near me" 
          class="group bg-white rounded-xl border border-onyx-mauve/20 p-4 text-left hover:border-verdant-forest hover:shadow-md transition-all duration-200">
          <div class="w-10 h-10 rounded-lg bg-verdant-forest/10 flex items-center justify-center mb-3 group-hover:bg-verdant-forest/20 transition-colors">
            <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.87c1.355 0 2.697.055 4.024.165C17.155 8.51 18 9.473 18 10.608v2.513m-3-4.87v-1.5m-6 1.5v-1.5m12 9.75l-4.5 4.5-3-3-3 3-4.5-4.5" />
            </svg>
          </div>
          <h3 class="font-medium text-onyx-deep">Local Food</h3>
          <p class="text-xs text-onyx-mauve mt-1">Authentic Kenyan cuisine nearby</p>
        </button>

        <button phx-click="send-message" phx-value-message="Is the area around me calm right now?" 
          class="group bg-white rounded-xl border border-onyx-mauve/20 p-4 text-left hover:border-verdant-forest hover:shadow-md transition-all duration-200">
          <div class="w-10 h-10 rounded-lg bg-verdant-forest/10 flex items-center justify-center mb-3 group-hover:bg-verdant-forest/20 transition-colors">
            <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
          </div>
          <h3 class="font-medium text-onyx-deep">Safety Check</h3>
          <p class="text-xs text-onyx-mauve mt-1">Real-time area safety status</p>
        </button>

        <button phx-click="send-message" phx-value-message="Best way to get to Jomo Kenyatta Airport" 
          class="group bg-white rounded-xl border border-onyx-mauve/20 p-4 text-left hover:border-verdant-forest hover:shadow-md transition-all duration-200">
          <div class="w-10 h-10 rounded-lg bg-verdant-forest/10 flex items-center justify-center mb-3 group-hover:bg-verdant-forest/20 transition-colors">
            <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.22-1.113-.615-1.53a15.12 15.12 0 00-2.207-1.625M13.5 5.25L12 3.75 9 6.75" />
            </svg>
          </div>
          <h3 class="font-medium text-onyx-deep">Directions</h3>
          <p class="text-xs text-onyx-mauve mt-1">Get there with verified transport</p>
        </button>

        <button phx-click="send-message" phx-value-message="Any events or cultural activities happening today?" 
          class="group bg-white rounded-xl border border-onyx-mauve/20 p-4 text-left hover:border-verdant-forest hover:shadow-md transition-all duration-200">
          <div class="w-10 h-10 rounded-lg bg-verdant-forest/10 flex items-center justify-center mb-3 group-hover:bg-verdant-forest/20 transition-colors">
            <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" />
            </svg>
          </div>
          <h3 class="font-medium text-onyx-deep">Events</h3>
          <p class="text-xs text-onyx-mauve mt-1">Live music, markets, festivals</p>
        </button>
      </div>

      <!-- AI Chat Section -->
      <div class="flex-1">
        <div :if={@messages == []} class="flex flex-col items-center text-center py-8">
          <div class="w-16 h-16 rounded-full bg-verdant-forest/10 flex items-center justify-center mb-4">
            <svg class="w-8 h-8 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M3 9.75a9 9 0 1118 0 9 9 0 01-18 0z" />
            </svg>
          </div>
          <h2 class="text-lg font-medium text-onyx-deep">Ask Mtaani AI</h2>
          <p class="text-sm text-onyx-mauve mt-1 max-w-xs">Get personalized recommendations, safety updates, and local insights</p>
        </div>

        <div :if={@messages != []} class="space-y-4 pb-4 custom-scrollbar">
          <%= for message <- @messages do %>
            <div class={[
              "flex message-fade-in",
              message.role == :user && "justify-end",
              message.role == :assistant && "justify-start"
            ]}>
              <div class={[
                "max-w-[85%] rounded-2xl px-4 py-3",
                message.role == :user && "bg-verdant-forest text-white",
                message.role == :assistant && "bg-onyx-mauve/10 text-onyx-deep"
              ]}>
                <p class="text-sm"><%= message.content %></p>
                <p class="text-xs opacity-60 mt-1">
                  <%= Calendar.strftime(message.timestamp, "%H:%M") %>
                </p>
              </div>
            </div>
          <% end %>
          
          <div :if={@thinking} class="flex justify-start">
            <div class="bg-onyx-mauve/10 rounded-2xl px-4 py-3">
              <div class="flex space-x-1">
                <div class="w-2 h-2 bg-verdant-forest rounded-full animate-bounce"></div>
                <div class="w-2 h-2 bg-verdant-forest rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                <div class="w-2 h-2 bg-verdant-forest rounded-full animate-bounce" style="animation-delay: 0.4s"></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Input Area -->
      <div class="border-t border-onyx-mauve/20 pt-4 mt-4">
        <form phx-submit="send-message" class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@input_text}
            phx-change="update-input"
            placeholder="Ask me anything..."
            class="flex-1 bg-onyx-mauve/5 border border-onyx-mauve/20 rounded-full px-5 py-3 text-onyx-deep placeholder-onyx-mauve focus:outline-none focus:border-verdant-forest focus:ring-1 focus:ring-verdant-forest"
          />
          <button
            type="submit"
            class="bg-verdant-forest hover:bg-verdant-deep text-white rounded-full px-5 py-3 transition-colors disabled:opacity-50"
            disabled={@thinking}
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </form>
        
        <div class="flex justify-between items-center mt-3 text-xs text-onyx-mauve">
          <div class="flex items-center gap-2">
            <span :if={@user_location} class="flex items-center gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-verdant-sage"></span>
              <span>📍 Located</span>
            </span>
            <span :if={!@user_location} class="flex items-center gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-onyx-mauve animate-pulse"></span>
              <span>📍 Getting location...</span>
            </span>
          </div>
          <span :if={@current_vibe == :calm} class="px-2 py-0.5 rounded-full text-xs font-medium bg-verdant-sage/20 text-verdant-sage">
            Calm area
          </span>
        </div>
      </div>
    </div>
    """
  end
end