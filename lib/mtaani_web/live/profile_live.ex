defmodule MtaaniWeb.ProfileLive do
  use MtaaniWeb, :live_view
  import Phoenix.LiveView, only: [push_navigate: 2, put_flash: 3, push_event: 3]

  alias Mtaani.Repo
  alias Mtaani.Accounts
  alias Mtaani.Accounts.User
  alias Mtaani.Social.Post

  # ============================================================================
  # Mount
  # ============================================================================

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if user_id do
      current_user = Accounts.get_user(user_id)

      if current_user do
        {:ok,
         socket
         |> assign_defaults(current_user)
         |> assign(:current_user, current_user)
         |> assign(:profile_user, current_user)
         |> assign(:is_own_profile, true)
         |> assign(:active_tab, "posts")
         |> assign(:edit_modal_open, false)
         |> assign(:show_emergency, false)
         |> load_profile_data(current_user)}
      else
        {:ok, push_navigate(socket, to: "/")}
      end
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  @impl true
  def mount(%{"username" => username}, session, socket) do
    user_id = session["user_id"]
    current_user = if user_id, do: Accounts.get_user(user_id), else: nil
    profile_user = Accounts.get_user_by_username(username)

    if profile_user do
      {:ok,
       socket
       |> assign_defaults(profile_user)
       |> assign(:current_user, current_user)
       |> assign(:profile_user, profile_user)
       |> assign(:is_own_profile, current_user && current_user.id == profile_user.id)
       |> assign(:active_tab, "posts")
       |> assign(:edit_modal_open, false)
       |> assign(:show_emergency, false)
       |> load_profile_data(profile_user)}
    else
      {:ok, push_navigate(socket, to: "/")}
    end
  end

  defp assign_defaults(socket, user) do
    socket
    |> assign(:avatar_initials, get_initials(user.name))
    |> assign(:avatar_color, get_avatar_color(user.id))
  end

  defp load_profile_data(socket, user) do
    stats = Accounts.get_user_stats(user)
    trust = Accounts.calculate_trust_score(user)
    {posts, total_posts} = Accounts.get_user_posts(user.id, 1, 20)
    photos_data = Accounts.get_user_photos_with_albums(user.id)
    visited_places = Accounts.get_visited_places(user.id, 8)

    connected_buddies =
      if socket.assigns.is_own_profile,
        do: Accounts.get_connected_buddies(user.id),
        else: []

    suggested_buddies =
      if socket.assigns.is_own_profile,
        do: Accounts.get_suggested_buddies(user.id, 8),
        else: []

    badges = Accounts.get_user_badges(user.id)

    is_following =
      if socket.assigns.current_user && !socket.assigns.is_own_profile,
        do: Accounts.following?(socket.assigns.current_user.id, user.id),
        else: false

    socket
    |> assign(:stats, stats)
    |> assign(:trust, trust)
    |> assign(:posts, posts)
    |> assign(:total_posts, total_posts)
    |> assign(:posts_page, 1)
    |> assign(:has_more_posts, length(posts) < total_posts)
    |> assign(:albums, photos_data.albums)
    |> assign(:recent_photos, photos_data.recent_photos)
    |> assign(:visited_places, visited_places)
    |> assign(:connected_buddies, connected_buddies)
    |> assign(:suggested_buddies, suggested_buddies)
    |> assign(:badges, badges)
    |> assign(:is_following, is_following)
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

  # ============================================================================
  # Tab Navigation
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("load_more_posts", _, socket) do
    next_page = socket.assigns.posts_page + 1
    {new_posts, total} = Accounts.get_user_posts(socket.assigns.profile_user.id, next_page, 20)

    {:noreply,
     socket
     |> update(:posts, &(&1 ++ new_posts))
     |> assign(:posts_page, next_page)
     |> assign(:has_more_posts, length(socket.assigns.posts) + length(new_posts) < total)}
  end

  # ============================================================================
  # Edit Profile Modal
  # ============================================================================

  @impl true
  def handle_event("open_edit_modal", _, socket) do
    {:noreply, assign(socket, :edit_modal_open, true)}
  end

  @impl true
  def handle_event("close_edit_modal", _, socket) do
    {:noreply, assign(socket, :edit_modal_open, false)}
  end

  @impl true
  def handle_event("update_profile", %{"profile" => profile_params}, socket) do
    user = socket.assigns.profile_user

    travel_vibes =
      if profile_params["travel_vibes"] do
        String.split(profile_params["travel_vibes"], ",") |> Enum.map(&String.trim/1)
      else
        []
      end

    attrs = %{
      name: profile_params["name"],
      bio: profile_params["bio"],
      location: profile_params["location"],
      website: profile_params["website"],
      traveler_type: profile_params["traveler_type"],
      is_private: profile_params["is_private"] == "true",
      travel_vibes: travel_vibes
    }

    case Accounts.update_profile(user, attrs) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:profile_user, updated_user)
         |> assign(:edit_modal_open, false)
         |> put_flash(:info, "Profile updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_errors, changeset.errors)}
    end
  end

  # ============================================================================
  # Follow / Unfollow
  # ============================================================================

  @impl true
  def handle_event("follow_user", _, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    if current_user && current_user.id != profile_user.id do
      Accounts.follow_user(current_user.id, profile_user.id)

      {:noreply,
       socket
       |> assign(:is_following, true)
       |> update(:stats, fn stats ->
         %{stats | followers_count: stats.followers_count + 1}
       end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unfollow_user", _, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    if current_user && current_user.id != profile_user.id do
      Accounts.unfollow_user(current_user.id, profile_user.id)

      {:noreply,
       socket
       |> assign(:is_following, false)
       |> update(:stats, fn stats ->
         %{stats | followers_count: max(0, stats.followers_count - 1)}
       end)}
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Navigation & Emergency
  # ============================================================================

  @impl true
  def handle_event("navigate", %{"to" => path}, socket) do
    {:noreply, push_navigate(socket, to: path)}
  end

  @impl true
  def handle_event("open_chat", _, socket) do
    {:noreply, push_navigate(socket, to: "/chat")}
  end

  @impl true
  def handle_event("share_profile", _, socket) do
    {:noreply,
     push_event(socket, "share_profile", %{username: socket.assigns.profile_user.username})}
  end

  @impl true
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end

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

  # ============================================================================
  # Upload Events
  # ============================================================================

  @impl true
  def handle_event("upload_cover_photo", _, socket) do
    {:noreply, push_event(socket, "trigger_cover_upload", %{})}
  end

  @impl true
  def handle_event("upload_profile_photo", _, socket) do
    {:noreply, push_event(socket, "trigger_profile_upload", %{})}
  end

  def handle_event("cover_uploaded", %{"url" => url}, socket) do
    {:ok, user} = Accounts.update_cover_photo(socket.assigns.profile_user, url)
    {:noreply, assign(socket, :profile_user, user)}
  end

  def handle_event("profile_photo_uploaded", %{"url" => url}, socket) do
    {:ok, user} = Accounts.update_profile_photo(socket.assigns.profile_user, url)
    {:noreply, assign(socket, :profile_user, user)}
  end

  # ============================================================================
  # Time Helper
  # ============================================================================

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[var(--color-background-tertiary)]">
      <div class="max-w-md mx-auto relative">
        <!-- Cover Photo -->
        <div class="relative h-44 bg-gradient-to-r from-[#064e3b] via-[#065f46] to-[#059669]">
          <%= if @profile_user.cover_photo_url do %>
            <img src={@profile_user.cover_photo_url} class="w-full h-full object-cover" />
          <% end %>
          
          <div class="absolute top-3 left-3 right-3 flex justify-between">
            <button
              phx-click="navigate"
              phx-value-to="/home"
              class="w-8 h-8 rounded-full bg-black/30 backdrop-blur-sm text-white"
            >
              ←
            </button>
            <div class="flex gap-2">
              <button class="w-8 h-8 rounded-full bg-black/30 backdrop-blur-sm text-white">🔍</button>
              <%= if @is_own_profile do %>
                <button
                  phx-click="open_edit_modal"
                  class="w-8 h-8 rounded-full bg-black/30 backdrop-blur-sm text-white"
                >
                  ✏️
                </button>
              <% end %>
            </div>
          </div>
          
          <%= if @is_own_profile do %>
            <button
              phx-click="upload_cover_photo"
              class="absolute bottom-3 right-3 bg-black/40 backdrop-blur-sm rounded-full px-3 py-1.5 text-xs text-white"
            >
              📷 Edit cover
            </button>
          <% end %>
        </div>
        
    <!-- Avatar -->
        <div class="px-4 -mt-9 relative z-10 flex justify-between items-end">
          <div class="relative">
            <div
              class="w-20 h-20 rounded-full flex items-center justify-center text-white text-2xl font-medium border-3 border-[var(--color-background-primary)]"
              style={"background: #{@avatar_color}"}
            >
              <%= if @profile_user.profile_photo_url do %>
                <img
                  src={@profile_user.profile_photo_url}
                  class="w-full h-full rounded-full object-cover"
                />
              <% else %>
                {@avatar_initials}
              <% end %>
              
              <%= if @is_own_profile do %>
                <button
                  phx-click="upload_profile_photo"
                  class="absolute bottom-0 right-0 w-6 h-6 rounded-full bg-verdant-forest border-2 border-white flex items-center justify-center text-xs"
                >
                  📷
                </button>
              <% end %>
            </div>
          </div>
          
          <div class="flex gap-2 pb-1">
            <%= if @is_own_profile do %>
              <button
                phx-click="open_edit_modal"
                class="px-4 py-2 rounded-xl text-xs font-medium bg-verdant-forest text-white"
              >
                ✏ Edit profile
              </button>
            <% else %>
              <button
                phx-click={if @is_following, do: "unfollow_user", else: "follow_user"}
                class={"px-4 py-2 rounded-xl text-xs font-medium " <> if(@is_following, do: "bg-[var(--color-background-secondary)] border", else: "bg-verdant-forest text-white")}
              >
                {if @is_following, do: "Following", else: "Follow"}
              </button>
            <% end %>
            
            <button
              phx-click="share_profile"
              class="px-4 py-2 rounded-xl text-xs font-medium bg-[var(--color-background-secondary)] border"
            >
              Share
            </button>
            <button
              phx-click="open_chat"
              class="w-9 h-9 rounded-xl bg-[var(--color-background-secondary)] border flex items-center justify-center"
            >
              💬
            </button>
          </div>
        </div>
        
    <!-- Identity -->
        <div class="px-4 pt-3">
          <h1 class="text-xl font-medium text-[var(--color-text-primary)]">{@profile_user.name}</h1>
          
          <p class="text-sm text-[var(--color-text-secondary)]">@{@profile_user.username}</p>
          
          <%= if @profile_user.bio do %>
            <p class="text-sm text-[var(--color-text-primary)] mt-2">{@profile_user.bio}</p>
          <% end %>
        </div>
        
    <!-- Stats -->
        <div class="mx-4 my-4 grid grid-cols-4 gap-0 border rounded-xl overflow-hidden bg-[var(--color-background-primary)]">
          <div class="py-3 text-center border-r">
            <div class="text-lg font-medium">{@stats.trips_count}</div>
            <div class="text-[9px] text-[var(--color-text-secondary)]">Trips</div>
          </div>
          
          <div class="py-3 text-center border-r">
            <div class="text-lg font-medium">{@stats.counties_count}</div>
            <div class="text-[9px] text-[var(--color-text-secondary)]">Counties</div>
          </div>
          
          <div class="py-3 text-center border-r">
            <div class="text-lg font-medium">{@stats.buddies_count}</div>
            <div class="text-[9px] text-[var(--color-text-secondary)]">Buddies</div>
          </div>
          
          <div class="py-3 text-center">
            <div class="text-lg font-medium">{@stats.followers_count}</div>
            <div class="text-[9px] text-[var(--color-text-secondary)]">Followers</div>
          </div>
        </div>
        
    <!-- Tabs -->
        <div class="sticky top-0 z-10 bg-[var(--color-background-primary)] border-b">
          <div class="flex">
            <button
              phx-click="switch_tab"
              phx-value-tab="posts"
              class={"flex-1 py-3 text-xs font-medium " <> if(@active_tab == "posts", do: "text-verdant-forest border-b-2 border-verdant-forest", else: "text-[var(--color-text-secondary)]")}
            >
              Posts
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="places"
              class={"flex-1 py-3 text-xs font-medium " <> if(@active_tab == "places", do: "text-verdant-forest border-b-2 border-verdant-forest", else: "text-[var(--color-text-secondary)]")}
            >
              Places
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="photos"
              class={"flex-1 py-3 text-xs font-medium " <> if(@active_tab == "photos", do: "text-verdant-forest border-b-2 border-verdant-forest", else: "text-[var(--color-text-secondary)]")}
            >
              Photos
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="dna"
              class={"flex-1 py-3 text-xs font-medium " <> if(@active_tab == "dna", do: "text-verdant-forest border-b-2 border-verdant-forest", else: "text-[var(--color-text-secondary)]")}
            >
              Travel DNA
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="buddies"
              class={"flex-1 py-3 text-xs font-medium " <> if(@active_tab == "buddies", do: "text-verdant-forest border-b-2 border-verdant-forest", else: "text-[var(--color-text-secondary)]")}
            >
              Buddies
            </button>
          </div>
        </div>
        
    <!-- Posts Panel -->
        <div class={if(@active_tab != "posts", do: "hidden")}>
          <div class="p-4 space-y-3">
            <%= for post <- @posts do %>
              <div class="bg-[var(--color-background-primary)] rounded-xl border p-3">
                <div class="flex items-center gap-3">
                  <div class="w-9 h-9 rounded-full bg-verdant-forest flex items-center justify-center text-white text-xs">
                    {get_initials(post.user.name)}
                  </div>
                  
                  <div>
                    <div class="text-sm font-medium">{post.user.name}</div>
                    <div class="text-xs text-[var(--color-text-secondary)]">
                      {time_ago(post.inserted_at)}
                    </div>
                  </div>
                </div>
                
                <div class="mt-2 text-sm">{post.content}</div>
              </div>
            <% end %>
            
            <%= if @posts == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No posts yet</div>
            <% end %>
          </div>
        </div>
        
    <!-- Places Panel -->
        <div class={if(@active_tab != "places", do: "hidden")}>
          <div class="p-4 text-center text-[var(--color-text-secondary)]">
            Places tab - Add visited places to see them here
          </div>
        </div>
        
    <!-- Photos Panel -->
        <div class={if(@active_tab != "photos", do: "hidden")}>
          <div class="p-4">
            <div class="grid grid-cols-3 gap-1">
              <%= for photo <- Enum.take(@recent_photos, 9) do %>
                <div class="aspect-square bg-[var(--color-background-secondary)]">
                  <img src={photo.url} class="w-full h-full object-cover" />
                </div>
              <% end %>
            </div>
            
            <%= if @recent_photos == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No photos yet</div>
            <% end %>
          </div>
        </div>
        
    <!-- Travel DNA Panel -->
        <div class={if(@active_tab != "dna", do: "hidden")}>
          <div class="p-4">
            <div class="bg-[var(--color-background-primary)] rounded-xl border p-4">
              <div class="flex justify-between items-center">
                <div>
                  <div class="text-xs text-[var(--color-text-secondary)]">Community standing</div>
                  <div class="font-medium">{@trust.level}</div>
                </div>
                
                <div class="relative w-11 h-11">
                  <div class="absolute inset-0 flex items-center justify-center text-xs font-medium">
                    {@trust.score}%
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Buddies Panel -->
        <div class={if(@active_tab != "buddies", do: "hidden")}>
          <div class="p-4 space-y-2">
            <%= for buddy <- @connected_buddies do %>
              <div class="bg-[var(--color-background-primary)] rounded-xl border p-3 flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-verdant-forest flex items-center justify-center text-white text-xs">
                  {get_initials(buddy.name)}
                </div>
                
                <div>
                  <div class="text-sm font-medium">{buddy.name}</div>
                  <div class="text-xs text-[var(--color-text-secondary)]">
                    {buddy.location || "Kenya"}
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if @connected_buddies == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No buddies yet</div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Edit Modal -->
      <%= if @edit_modal_open do %>
        <div class="fixed inset-0 bg-black/50 flex items-end z-50" phx-click="close_edit_modal">
          <div
            class="bg-[var(--color-background-primary)] rounded-t-2xl w-full max-h-[88%] overflow-y-auto"
            phx-click="preventDefault"
          >
            <div class="w-8 h-1 bg-[var(--color-border-secondary)] rounded-full mx-auto mt-3 mb-2">
            </div>
            
            <div class="flex justify-between px-5 pb-3 border-b">
              <h2 class="text-base font-medium">Edit profile</h2>
              
              <button
                type="button"
                phx-click="close_edit_modal"
                class="text-sm font-medium text-verdant-forest"
              >
                Save
              </button>
            </div>
            
            <form phx-submit="update_profile" class="pb-8">
              <div class="relative h-24 bg-gradient-to-r from-[#064e3b] to-[#065f46]"></div>
              
              <div class="px-5 pt-12 space-y-4">
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">Name</label>
                  <input
                    type="text"
                    name="profile[name]"
                    value={@profile_user.name}
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  />
                </div>
                
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">Bio</label><textarea
                    name="profile[bio]"
                    rows="3"
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  ><%= @profile_user.bio || "" %></textarea>
                </div>
                
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">Location</label>
                  <input
                    type="text"
                    name="profile[location]"
                    value={@profile_user.location || ""}
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  />
                </div>
                
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">Website</label>
                  <input
                    type="text"
                    name="profile[website]"
                    value={@profile_user.website || ""}
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  />
                </div>
                
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">Traveler type</label>
                  <select
                    name="profile[traveler_type]"
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  >
                    <option value="Traveler" selected={@profile_user.traveler_type == "Traveler"}>
                      Traveler
                    </option>
                    
                    <option
                      value="Local guide"
                      selected={@profile_user.traveler_type == "Local guide"}
                    >
                      Local guide
                    </option>
                    
                    <option
                      value="Local resident"
                      selected={@profile_user.traveler_type == "Local resident"}
                    >
                      Local resident
                    </option>
                    
                    <option value="Business" selected={@profile_user.traveler_type == "Business"}>
                      Business
                    </option>
                  </select>
                </div>
                
                <div>
                  <label class="text-xs text-[var(--color-text-secondary)]">
                    Travel vibes (comma separated)
                  </label>
                  <input
                    type="text"
                    name="profile[travel_vibes]"
                    value={Enum.join(@profile_user.travel_vibes || [], ", ")}
                    class="w-full mt-1 px-3 py-2 text-sm bg-[var(--color-background-secondary)] border rounded-xl"
                  />
                </div>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
