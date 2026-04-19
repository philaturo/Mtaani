defmodule MtaaniWeb.ProfileSetupLive do
  use MtaaniWeb, :live_view
  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3, push_event: 3]

  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      send(self(), :request_geolocation)
    end

    user_id = session["user_id"]

    if is_nil(user_id) do
      {:ok, push_navigate(socket, to: "/")}
    else
      current_user = Mtaani.Repo.get(User, user_id)

      if is_nil(current_user) do
        {:ok, push_navigate(socket, to: "/")}
      else
        {:ok,
         socket
         |> assign(:step, 3)
         |> assign(:current_user, current_user)
         |> assign(:bio, current_user.bio || "")
         |> assign(:bio_count, String.length(current_user.bio || ""))
         |> assign(:traveler_type, "traveler")
         |> assign(:location_enabled, true)
         |> assign(:avatar_url, current_user.profile_photo_url)
         |> assign(:avatar_initials, get_initials(current_user.name))
         |> assign(:avatar_color, get_avatar_color(current_user.id))
         |> assign(:show_emergency, false)
         |> assign(:saving, false)
         |> assign(:error, nil)
         |> assign(:success, nil)}
      end
    end
  end

  @impl true
  def handle_info(:request_geolocation, socket) do
    {:noreply, push_event(socket, "request_geolocation", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20">
      <div class="max-w-md mx-auto px-4 py-8">
        <div class="mb-6">
          <div class="flex items-center justify-between mb-6">
            <button
              phx-click="go_back"
              class="w-10 h-10 rounded-full bg-white/80 border border-onyx-mauve/20 flex items-center justify-center"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <polyline points="15 18 9 12 15 6"></polyline>
              </svg>
            </button>
            
            <button phx-click="skip" class="text-sm text-verdant-forest font-medium">
              Skip for now
            </button>
          </div>
          
          <div class="flex items-center gap-2 justify-center mb-4">
            <div class="w-2 h-1 rounded-full bg-verdant-forest"></div>
            
            <div class="w-2 h-1 rounded-full bg-verdant-forest"></div>
            
            <div class="w-5 h-1 rounded-full bg-verdant-forest"></div>
          </div>
          
          <div class="flex items-center gap-2 mb-2">
            <div class="w-2 h-2 rounded-full bg-verdant-forest"></div>
             <span class="text-xs font-medium text-verdant-forest">Mtaani</span>
          </div>
          
          <h1 class="text-2xl font-semibold text-onyx-deep mb-2">Build your profile</h1>
          
          <p class="text-sm text-onyx-mauve">Help the community know you. This takes 60 seconds.</p>
        </div>
        
        <div class="bg-white/80 backdrop-blur-sm rounded-2xl border border-onyx-mauve/20 p-6 space-y-5">
          <!-- Avatar Picker -->
          <div class="flex flex-col items-center">
            <div class="relative cursor-pointer group" phx-click="change_avatar">
              <div
                class="w-24 h-24 rounded-full flex items-center justify-center text-2xl font-semibold text-white shadow-lg transition-transform group-hover:scale-105"
                style={"background: #{@avatar_color}"}
              >
                <%= if @avatar_url do %>
                  <img src={@avatar_url} class="w-full h-full rounded-full object-cover" />
                <% else %>
                  {@avatar_initials}
                <% end %>
              </div>
              
              <div class="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-verdant-forest border-2 border-white flex items-center justify-center">
                <svg
                  class="w-4 h-4 text-white"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                </svg>
              </div>
            </div>
            
            <p class="text-xs text-onyx-mauve mt-2">Tap to add a profile photo</p>
          </div>
          
    <!-- Bio -->
          <div>
            <label class="block text-xs font-medium text-onyx-deep mb-1">Short bio</label>
            <div class="border border-onyx-mauve/20 rounded-lg overflow-hidden bg-white focus-within:border-verdant-forest">
              <textarea
                rows="3"
                value={@bio}
                phx-change="update_bio"
                placeholder="e.g., Adventure seeker. Based in Nairobi. Love safaris and hiking."
                class="w-full px-3 py-2 outline-none text-sm resize-none"
                maxlength="120"
              ><%= @bio %></textarea>
            </div>
            
            <div class="flex justify-between mt-1">
              <p class="text-xs text-onyx-mauve">Tell the community about yourself</p>
              
              <p class="text-xs text-onyx-mauve">{@bio_count} / 120</p>
            </div>
          </div>
          
    <!-- Traveler Type -->
          <div>
            <label class="block text-xs font-medium text-onyx-deep mb-2">I am a</label>
            <div class="grid grid-cols-2 gap-2">
              <button
                type="button"
                phx-click="select_type"
                phx-value-type="traveler"
                class={[
                  "p-3 rounded-xl border-2 text-left transition-all",
                  @traveler_type == "traveler" && "border-verdant-forest bg-verdant-sage/5",
                  @traveler_type != "traveler" &&
                    "border-onyx-mauve/20 hover:border-verdant-forest/50"
                ]}
              >
                <div class="flex items-center gap-2 mb-1">
                  <div class="w-8 h-8 rounded-lg bg-verdant-sage/10 flex items-center justify-center">
                    <svg
                      class="w-4 h-4 text-verdant-forest"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                      <circle cx="12" cy="10" r="3" />
                    </svg>
                  </div>
                   <span class="font-medium text-sm text-onyx-deep">Traveler</span>
                </div>
                
                <p class="text-xs text-onyx-mauve">Exploring Kenya for the first time or nth time</p>
              </button>
              
              <button
                type="button"
                phx-click="select_type"
                phx-value-type="guide"
                class={[
                  "p-3 rounded-xl border-2 text-left transition-all",
                  @traveler_type == "guide" && "border-verdant-forest bg-verdant-sage/5",
                  @traveler_type != "guide" && "border-onyx-mauve/20 hover:border-verdant-forest/50"
                ]}
              >
                <div class="flex items-center gap-2 mb-1">
                  <div class="w-8 h-8 rounded-lg bg-blue-50 flex items-center justify-center">
                    <svg
                      class="w-4 h-4 text-blue-600"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <circle cx="12" cy="12" r="10" /> <line x1="2" y1="12" x2="22" y2="12" />
                      <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                    </svg>
                  </div>
                   <span class="font-medium text-sm text-onyx-deep">Local guide</span>
                </div>
                
                <p class="text-xs text-onyx-mauve">I know Kenya well and want to guide others</p>
              </button>
              
              <button
                type="button"
                phx-click="select_type"
                phx-value-type="resident"
                class={[
                  "p-3 rounded-xl border-2 text-left transition-all",
                  @traveler_type == "resident" && "border-verdant-forest bg-verdant-sage/5",
                  @traveler_type != "resident" &&
                    "border-onyx-mauve/20 hover:border-verdant-forest/50"
                ]}
              >
                <div class="flex items-center gap-2 mb-1">
                  <div class="w-8 h-8 rounded-lg bg-purple-50 flex items-center justify-center">
                    <svg
                      class="w-4 h-4 text-purple-600"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                      <polyline points="9 22 9 12 15 12 15 22" />
                    </svg>
                  </div>
                   <span class="font-medium text-sm text-onyx-deep">Local resident</span>
                </div>
                
                <p class="text-xs text-onyx-mauve">I live here and want to connect with visitors</p>
              </button>
              
              <button
                type="button"
                phx-click="select_type"
                phx-value-type="business"
                class={[
                  "p-3 rounded-xl border-2 text-left transition-all",
                  @traveler_type == "business" && "border-verdant-forest bg-verdant-sage/5",
                  @traveler_type != "business" &&
                    "border-onyx-mauve/20 hover:border-verdant-forest/50"
                ]}
              >
                <div class="flex items-center gap-2 mb-1">
                  <div class="w-8 h-8 rounded-lg bg-orange-50 flex items-center justify-center">
                    <svg
                      class="w-4 h-4 text-orange-600"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path d="M14.5 10c-.83 0-1.5-.67-1.5-1.5v-5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5v5c0 .83-.67 1.5-1.5 1.5z" />
                    </svg>
                  </div>
                   <span class="font-medium text-sm text-onyx-deep">Business</span>
                </div>
                
                <p class="text-xs text-onyx-mauve">Hotel, tour operator, or travel business</p>
              </button>
            </div>
          </div>
          
    <!-- Location Permission -->
          <div class="bg-verdant-sage/5 rounded-xl border border-verdant-sage/20 p-3 flex gap-3">
            <div class="w-10 h-10 rounded-lg bg-verdant-sage/10 flex items-center justify-center flex-shrink-0">
              <svg
                class="w-5 h-5 text-verdant-forest"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                <circle cx="12" cy="10" r="3" />
              </svg>
            </div>
            
            <div class="flex-1">
              <div class="text-xs font-medium text-onyx-deep mb-1">Enable location for safety</div>
              
              <div class="text-xs text-onyx-mauve">
                Mtaani uses your location to show nearby safe zones, verified guides, and real-time area activity. Never shared without permission.
              </div>
            </div>
            
            <button
              phx-click="toggle_location"
              class={[
                "w-10 h-6 rounded-full transition-all flex-shrink-0 mt-1",
                @location_enabled && "bg-verdant-forest justify-end",
                !@location_enabled && "bg-onyx-mauve/30 justify-start"
              ]}
            >
              <div class="w-5 h-5 rounded-full bg-white shadow-sm transform transition-transform">
              </div>
            </button>
          </div>
          
          <%= if @error do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-3">
              <p class="text-red-600 text-sm">{@error}</p>
            </div>
          <% end %>
          
          <%= if @success do %>
            <div class="bg-green-50 border border-green-200 rounded-lg p-3">
              <p class="text-green-600 text-sm">{@success}</p>
            </div>
          <% end %>
          
          <button
            phx-click="complete_setup"
            disabled={@saving}
            class="w-full bg-verdant-forest text-white py-3 rounded-lg font-medium hover:bg-verdant-deep transition-all disabled:opacity-50"
          >
            <%= if @saving do %>
              <div class="flex items-center justify-center gap-2">
                <div class="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin">
                </div>
                 <span>Saving...</span>
              </div>
            <% else %>
              Complete setup
            <% end %>
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_bio", %{"value" => bio}, socket) do
    {:noreply,
     socket
     |> assign(:bio, bio)
     |> assign(:bio_count, String.length(bio))}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :traveler_type, type)}
  end

  @impl true
  def handle_event("toggle_location", _, socket) do
    {:noreply, assign(socket, :location_enabled, !socket.assigns.location_enabled)}
  end

  @impl true
  def handle_event("change_avatar", _, socket) do
    {:noreply, push_event(socket, "trigger_avatar_upload", %{})}
  end

  @impl true
  def handle_event("skip", _, socket) do
    {:noreply, push_navigate(socket, to: "/welcome")}
  end

  @impl true
  def handle_event("go_back", _, socket) do
    {:noreply, push_navigate(socket, to: "/verify")}
  end

  @impl true
  def handle_event("complete_setup", _, socket) do
    user = socket.assigns.current_user
    bio = socket.assigns.bio
    traveler_type = socket.assigns.traveler_type
    location_enabled = socket.assigns.location_enabled

    # Convert traveler_type to the format expected by the database
    traveler_type_value =
      case traveler_type do
        "traveler" -> "Traveler"
        "guide" -> "Local guide"
        "resident" -> "Local resident"
        "business" -> "Business"
        _ -> "Traveler"
      end

    # Prepare profile attributes
    attrs = %{
      bio: bio,
      traveler_type: traveler_type_value
    }

    # Add location if enabled
    attrs =
      if location_enabled and socket.assigns.user_location do
        Map.merge(attrs, %{
          location_lat: socket.assigns.user_location.lat,
          location_lng: socket.assigns.user_location.lng,
          last_active: DateTime.utc_now()
        })
      else
        attrs
      end

    # If user is a guide, mark them as guide and create guide profile
    if traveler_type == "guide" do
      attrs = Map.put(attrs, :is_guide, true)

      # Create guide profile
      Mtaani.Accounts.upsert_guide(user.id, %{
        bio: bio,
        availability_status: "online",
        verification_status: "pending",
        languages: [],
        years_experience: 0
      })
    end

    # Update user profile
    case Mtaani.Accounts.update_complete_profile(user, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile setup complete! Welcome to Mtaani.")
         |> push_navigate(to: "/welcome")}

      {:error, changeset} ->
        error_msg =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:noreply, assign(socket, :error, error_msg)}
    end
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

  @impl true
  def handle_event("location-update", %{"lat" => lat, "lng" => lng}, socket) do
    {:noreply, assign(socket, :user_location, %{lat: lat, lng: lng})}
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
