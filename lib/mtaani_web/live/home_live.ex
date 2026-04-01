defmodule MtaaniWeb.HomeLive do
  use MtaaniWeb, :live_view

  @impl true
def mount(_params, _session, socket) do
  # Get user from session (placeholder for now)
  user = %{name: "Explorer"}
  
  socket =
    socket
    |> assign(:active_tab, "home")
    |> assign(:user, user)
    |> assign(:messages, [])
    |> assign(:input_text, "")
    |> assign(:thinking, false)
    |> assign(:user_location, nil)
    |> assign(:current_vibe, :unknown)

  if connected?(socket) do
    # Subscribe to online count updates
    Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    # Request location
    send(self(), :request_location)
  end

  {:ok, socket}
end

    # Add this handler to receive online count updates
  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_info(:request_location, socket) do
    {:noreply, push_event(socket, "request-geolocation", %{})}
  end

  @impl true
  def handle_info({:ai_response, user_message}, socket) do
    # Placeholder AI response - will be replaced with real LLM call
    response = """
    I understand you're asking about "#{user_message}". 
    With your current location, I can help you find local spots, 
    check safety conditions, or give you directions. What would you like to do?
    """

    messages = socket.assigns.messages ++ [%{role: :assistant, content: response, timestamp: DateTime.utc_now()}]

    {:noreply, assign(socket, [messages: messages, thinking: false])}
  end

  # Navigation handler
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("location-update", %{"lat" => lat, "lng" => lng}, socket) do
    location = %{lat: lat, lng: lng}
    {:noreply,
     socket
     |> assign(:user_location, location)
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
  def handle_event("send-message", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col max-w-3xl mx-auto px-4 py-6 pb-20">
      <!-- Welcome Header -->
      <div class="mb-8">
        <h1 class="text-2xl font-semibold text-onyx-deep">Welcome back, <%= @user.name %></h1>
        <p class="text-onyx-mauve mt-1">What would you like to explore today?</p>
      </div>

      <!-- Quick Actions -->
      <div class="grid grid-cols-2 gap-3 mb-8">
        <button 
          phx-click="send-message" 
          phx-value-message="Check safety around my location"
          class="flex items-center gap-2 bg-white border border-onyx-mauve/20 rounded-xl px-4 py-3 hover:border-verdant-forest transition-colors"
        >
          <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
          </svg>
          <span class="text-sm text-onyx-deep">Safety check</span>
        </button>
        <button 
          phx-click="send-message" 
          phx-value-message="Best way to get to my destination"
          class="flex items-center gap-2 bg-white border border-onyx-mauve/20 rounded-xl px-4 py-3 hover:border-verdant-forest transition-colors"
        >
          <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.22-1.113-.615-1.53a15.12 15.12 0 00-2.207-1.625M13.5 5.25L12 3.75 9 6.75" />
          </svg>
          <span class="text-sm text-onyx-deep">Get there</span>
        </button>
      </div>

      <!-- AI Chat Section -->
      <div class="flex-1">
        <!-- Welcome / Empty State -->
        <div :if={@messages == []} class="flex-1 flex flex-col items-center justify-center text-center space-y-6">
          <div class="w-20 h-20 rounded-full bg-verdant-forest/10 flex items-center justify-center">
            <svg class="w-10 h-10 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M3 9.75a9 9 0 1118 0 9 9 0 01-18 0z" />
            </svg>
          </div>
          <h2 class="text-xl font-medium text-onyx-deep">How can I help you today?</h2>
          <p class="text-onyx-mauve max-w-md">
            Ask me about local food, safety conditions, directions, or cultural events in Nairobi.
          </p>
          
          <div class="flex flex-wrap justify-center gap-2 pt-4">
            <button phx-click="send-message" phx-value-message="Find me local food within walking distance" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
              Local food near me
            </button>
            <button phx-click="send-message" phx-value-message="Is the area around me calm right now?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
              Safety check
            </button>
            <button phx-click="send-message" phx-value-message="Best way to get to Jomo Kenyatta Airport?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
              Directions
            </button>
            <button phx-click="send-message" phx-value-message="Any events or vibes happening today?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
              What's happening
            </button>
          </div>
        </div>

        <!-- Chat Messages -->
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
              <span>Located in Nairobi</span>
            </span>
            <span :if={!@user_location} class="flex items-center gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-onyx-mauve animate-pulse"></span>
              <span>Getting your location...</span>
            </span>
          </div>
          <span :if={@current_vibe == :calm} class="px-2 py-0.5 rounded-full text-xs font-medium bg-verdant-sage/20 text-verdant-sage">
            Calm area
          </span>
          <span :if={@current_vibe == :bustling} class="px-2 py-0.5 rounded-full text-xs font-medium bg-verdant-clay/20 text-verdant-clay">
            Bustling
          </span>
        </div>
      </div>
    </div>
    """
  end
end