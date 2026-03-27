defmodule MtaaniWeb.HomeLive do
    use MtaaniWeb, :live_view

    @impl true
    def mount(_params, _session, socket) do
    # Get user location from session or default to Nairobi
    user_location = get_session(socket, :user_location) || %{lat: -1.2921, lng: 36.8219}

    socket = assign(socket,
    page_title: "Discover Kenya",
    user_location: user_location,
    map_center: user_location,
    map_zoom: 13,
    safety_heatmap_data: [],
    nearby_locations: [],
    ai_drawer_open: false,
    chat_messages: [
        %{role: "assistant", content: " Hi! I'm your Mtaani guide. Where would you like to explore today?"}
      ],
      chat_loading: false
    )
    
    {:ok, socket}
  end

  @impl true
  def handle_event("send_chat_message", %{"message" => message}, socket) when message != "" do
    # Add user message
    messages = socket.assigns.chat_messages ++ [%{role: "user", content: message}]
    socket = assign(socket, chat_messages: messages, chat_loading: true)
    
    # Simulate AI response (will connect to real AI later)
    send(self(), :simulate_ai_response)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info(:simulate_ai_response, socket) do
    responses = [
      "I've found several great spots near you! Would you like to see them on the map?",
      "Based on your location, I recommend Mama's Kitchen for authentic Kenyan food. 5 min walk, 95% safety rating.",
      "There's a music festival in Westlands tonight at 7 PM. Would you like me to show you the route?",
      "Current safety score in your area is 92%. The park is well-lit and busy with evening joggers."
    ]
    
    response = Enum.random(responses)
    
    messages = socket.assigns.chat_messages ++ [%{role: "assistant", content: response}]
    socket = assign(socket, chat_messages: messages, chat_loading: false)
    
    {:noreply, socket}
  end

  defp get_session(socket, key) do
    case get_connect_params(socket) do
      %{"session" => session} -> Map.get(session, key)
      _ -> nil
    end
  end
end
    