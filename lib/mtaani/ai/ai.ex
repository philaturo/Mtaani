defmodule Mtaani.AI do
  @moduledoc """
  AI Service for Mtaani - Intelligent travel assistant
  Uses Groq/Llama 3 for fast, accurate responses
  """

  alias Mtaani.Repo
  alias Mtaani.Places.Place
  alias Mtaani.SafetyZones.SafetyZone
  alias Mtaani.Incidents.Incident
  import Ecto.Query

  @groq_api_url "https://api.groq.com/openai/v1/chat/completions"

  # System prompt defining the AI's role and behavior
  @system_prompt """
  You are Mtaani AI, a smart, friendly travel assistant for Nairobi, Kenya.
  
  Your personality:
  - Warm and helpful, like a local friend
  - Knowledgeable about Nairobi's streets, culture, and safety
  - Honest about limitations - if you don't know something, say so clearly
  
  Your capabilities:
  - Recommend restaurants, cafes, attractions based on user preferences
  - Provide safety guidance using real-time data
  - Give directions using matatus, Uber, Bolt, or walking
  - Find events and cultural activities
  - Remember user preferences across conversations
  
  Important rules:
  - NEVER invent information. If data isn't available, say: "I don't have that information yet. Check back soon as we're continuously adding more places!"
  - Be concise. Keep responses under 150 words unless detailed info is requested.
  - Use local terms naturally (matatu, boda, bob, Kencom, CBD)
  - Prioritize safety in all recommendations
  - When suggesting places, include approximate distance and vibe (calm/bustling)
  
  Always be honest about data limitations. If the database is empty, say so politely.
  """

  @doc """
  Get a response from the AI based on user message and context
  """
  def chat(user_message, user_id, user_location \\ nil) do
    # 1. Get user context (preferences, history)
    user_context = get_user_context(user_id)
    
    # 2. Get location context (safety, nearby places)
    location_context = get_location_context(user_location)
    
    # 3. Build the prompt
    prompt = build_prompt(user_message, user_context, location_context)
    
    # 4. Call Groq API
    call_groq(prompt)
  end

  defp get_user_context(user_id) do
  user = Repo.get(Mtaani.Accounts.User, user_id)
  
  if user do
    %{
      name: user.name,
      preferences: user.preferences || %{}
    }
  else
    %{name: "Traveler", preferences: %{}}
  end
end

  defp get_location_context(nil), do: %{has_location: false}

  defp get_location_context(%{lat: lat, lng: lng}) do
    # Get safety zone for this location
    safety_zone = get_safety_zone(lat, lng)
    
    # Get recent incidents nearby
    incidents = get_nearby_incidents(lat, lng, 1000)  # 1km radius
    
    # Get nearby places
    nearby_places = get_nearby_places(lat, lng, 500)  # 500m radius
    
    %{
      has_location: true,
      lat: lat,
      lng: lng,
      safety_zone: safety_zone,
      incidents: incidents,
      nearby_places: nearby_places
    }
  end

 # This queries REAL database data - no placeholders -> to be implement later
# defp get_safety_zone(lat, lng) do
  # query = from sz in SafetyZone,
    # where: fragment("ST_Contains(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))", sz.area, ^lng, ^lat),
    # select: %{name: sz.name, incident_count: sz.incident_count}
  
  # Repo.one(query)  # Return REAL data from DB
# end

  
 # defp get_nearby_incidents(lat, lng, radius_m) do
    # Use fragment for PostGIS ST_DWithin function
  #  query = from i in Incident,
   #   where: fragment("ST_DWithin(?, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)", i.location, ^lng, ^lat, ^radius_m) and i.resolved == false,
    #  select: %{type: i.type, severity: i.severity, description: i.description},
     # limit: 5
    
   # Repo.all(query)
  #end

 # defp get_nearby_places(lat, lng, radius_m) do
  #  # Use fragment for PostGIS ST_DWithin function
   # query = from p in Place,
    #  where: fragment("ST_DWithin(?, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)", p.location, ^lng, ^lat, ^radius_m),
     # select: %{name: p.name, category: p.category, safety_score: p.safety_score},
      #limit: 10
    
   # Repo.all(query)
  #end

  defp get_safety_zone(_lat, _lng) do
  %{name: "Nairobi Area", incident_count: 0}
end

defp get_nearby_incidents(_lat, _lng, _radius_m) do
  []
end

defp get_nearby_places(_lat, _lng, _radius_m) do
  []
end

  defp build_prompt(user_message, user_context, location_context) do
  # Build context parts using explicit list accumulation
  initial_items = []
  
  # Add user context
  after_user = ["User: #{user_context.name}" | initial_items]
  
  after_prefs = if user_context.preferences != %{} do
    ["Preferences: #{inspect(user_context.preferences)}" | after_user]
  else
    after_user
  end

  # Add location context if available
  final_items = if location_context.has_location do
    location_text = """
    Current location: #{location_context.safety_zone.name}
    Incident count in area: #{location_context.safety_zone.incident_count}
    """
    after_location = [location_text | after_prefs]
    
    after_incidents = cond do
      length(location_context.incidents) > 0 ->
        incidents_text = "Recent incidents nearby: " <> Enum.map_join(location_context.incidents, ", ", &(&1.type))
        [incidents_text | after_location]
      
      length(location_context.nearby_places) > 0 ->
        places_text = "Nearby places: " <> Enum.map_join(location_context.nearby_places, ", ", &("#{&1.name} (#{&1.category})"))
        [places_text | after_location]
      
      true ->
        ["\n[SYSTEM NOTE: The Mtaani database is currently being populated with real-time data for Nairobi. You don't have specific place/incident data for this exact location yet. Be honest about this limitation.]" | after_location]
    end
    
    after_incidents
  else
    ["Location: Not shared. User hasn't enabled location services." | after_prefs]
  end

  context = Enum.join(Enum.reverse(final_items), "\n")

  """
  #{@system_prompt}
  
  Current context:
  #{context}
  
  User message: #{user_message}
  
  Important: If the database lacks specific data for this query, be honest and say:
  "I don't have specific data for that yet. Mtaani is currently expanding its coverage of Nairobi. 
  Could you try a different area or ask me about general information about Nairobi?"
  
  Respond as Mtaani AI. Be helpful, concise, and honest about any missing data.
  """
end

  defp call_groq(prompt) do
    api_key = Application.get_env(:mtaani, :groq_api_key) || System.get_env("GROQ_API_KEY")
    
    # Check if we have a valid API key
    has_valid_key = api_key && 
                    api_key != "" && 
                    String.starts_with?(api_key, "gsk_") &&
                    String.length(api_key) > 10
    
    if has_valid_key do
      case make_groq_request(prompt, api_key) do
        {:ok, response} -> {:ok, response}
        {:error, reason} -> 
          IO.puts("Groq API error: #{reason}. Falling back to simulation.")
          {:ok, simulate_ai_response(prompt)}
      end
    else
      IO.puts("No valid Groq API key found. Using simulated responses.")
      {:ok, simulate_ai_response(prompt)}
    end
  end

  defp make_groq_request(prompt, api_key) do
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
    
    body = %{
     model: "llama-3.1-8b-instant",
      messages: [
        %{role: "system", content: @system_prompt},
        %{role: "user", content: prompt}
      ],
      temperature: 0.7,
      max_tokens: 500
    }
    
    case HTTPoison.post(@groq_api_url, Jason.encode!(body), headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}}]}} ->
            {:ok, content}
          _ ->
            {:error, "Failed to parse AI response"}
        end
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "API error: #{status}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Connection error: #{reason}"}
    end
  end

  # Fallback simulation for development without API key
  defp simulate_ai_response(prompt) do
    cond do
      String.contains?(prompt, "food") or String.contains?(prompt, "restaurant") or String.contains?(prompt, "eat") ->
        "I'd love to recommend some local food spots! Based on your location, there are several options nearby. Mama's Kitchen is a local favorite for authentic Kenyan cuisine. Would you like directions or more details? (Note: This is a simulated response. Real AI responses will be available when the Groq API key is configured.)"
      
      String.contains?(prompt, "safe") or String.contains?(prompt, "safety") or String.contains?(prompt, "calm") ->
        "Safety is our top priority. Your current area is generally calm during the day. I recommend staying on main roads and being aware of your surroundings. Would you like me to show you the safest route to your destination? (Note: This is a simulated response. Real AI responses will be available when the Groq API key is configured.)"
      
      String.contains?(prompt, "direction") or String.contains?(prompt, "get to") or String.contains?(prompt, "route") ->
        "I can help with directions! Based on your location, I recommend using Uber or Bolt for reliable transport. Matatus are also available for budget-friendly travel. Where would you like to go? (Note: This is a simulated response. Real AI responses will be available when the Groq API key is configured.)"
      
      String.contains?(prompt, "event") or String.contains?(prompt, "happening") or String.contains?(prompt, "today") ->
        "Events are being added to our database. Check local venues like The Alchemist or Kenya National Theatre for current shows. I'll have more recommendations soon! (Note: This is a simulated response. Real AI responses will be available when the Groq API key is configured.)"
      
      true ->
        "I'm here to help! You can ask me about local restaurants, safety information, directions, transport options, or upcoming events. What would you like to know about Nairobi? (Note: This is a simulated response. Real AI responses will be available when the Groq API key is configured.)"
    end
  end

  # ==================== HELPER FUNCTIONS ====================
  
  @doc """
  Check what data is available in the database
  Add this function before the final 'end' of the module
  """
  def check_data_status do
    places_count = Repo.aggregate(Place, :count, :id)
    zones_count = Repo.aggregate(SafetyZone, :count, :id)
    incidents_count = Repo.aggregate(Incident, :count, :id)
    
    %{
      has_places: places_count > 0,
      has_safety_zones: zones_count > 0,
      has_incidents: incidents_count > 0,
      places_count: places_count,
      safety_zones_count: zones_count,
      incidents_count: incidents_count
    }
  end
  
end