defmodule MtaaniWeb.HomeLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:input_text, "")
      |> assign(:thinking, false)
      |> assign(:user_location, nil)
      |> assign(:current_vibe, :unknown)

    if connected?(socket) do
      send(self(), :request_location)
    end

    {:ok, socket}
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
    With your current location in Nairobi, I can help you find local spots, 
    check safety conditions, or give you directions. What would you like to do?
    """

    messages = socket.assigns.messages ++ [%{role: :assistant, content: response, timestamp: DateTime.utc_now()}]

   {:noreply, assign(socket, [messages: messages, thinking: false])}
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

    # Send to AI service (placeholder)
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
    <div class="h-full flex flex-col max-w-3xl mx-auto px-4 py-6">
      <!-- Welcome / Empty State -->
      <div :if={@messages == []} class="flex-1 flex flex-col items-center justify-center text-center space-y-6">
        <div class="w-20 h-20 rounded-full bg-verdant-forest/10 flex items-center justify-center">
          <span class="text-4xl">🌍</span>
        </div>
        <h1 class="text-2xl font-semibold text-onyx-deep">Welcome to Mtaani</h1>
        <p class="text-onyx-mauve max-w-md">
          Your personal guide to the streets of Kenya. Ask me anything — 
          from finding local food to checking safety conditions.
        </p>
        
        <div class="flex flex-wrap justify-center gap-2 pt-4">
          <button phx-click="send-message" phx-value-message="Find me local food within walking distance" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
            🍽️ Local food near me
          </button>
          <button phx-click="send-message" phx-value-message="Is the area around me calm right now?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
            🛡️ Is it calm here?
          </button>
          <button phx-click="send-message" phx-value-message="Best way to get to Jomo Kenyatta Airport?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
            🚗 How to get to the airport
          </button>
          <button phx-click="send-message" phx-value-message="Any events or vibes happening today?" class="px-4 py-2 bg-onyx-mauve/10 hover:bg-onyx-mauve/20 rounded-full text-sm text-onyx-deep transition-colors">
            🎉 What's happening?
          </button>
        </div>
      </div>

      <!-- Chat Messages -->
      <div :if={@messages != []} class="flex-1 overflow-y-auto space-y-4 pb-4 custom-scrollbar">
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

      <!-- Input Area -->
      <div class="border-t border-onyx-mauve/20 pt-4 mt-2">
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
              <span>📍 Located in Nairobi</span>
            </span>
            <span :if={!@user_location} class="flex items-center gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-onyx-mauve animate-pulse"></span>
              <span>📍 Getting your location...</span>
            </span>
          </div>
          <span :if={@current_vibe == :calm} class="px-2 py-0.5 rounded-full text-xs font-medium bg-verdant-sage/20 text-verdant-sage">
            🟢 Calm area
          </span>
          <span :if={@current_vibe == :bustling} class="px-2 py-0.5 rounded-full text-xs font-medium bg-verdant-clay/20 text-verdant-clay">
            🟡 Bustling
          </span>
        </div>
      </div>
    </div>
    """
  end
end