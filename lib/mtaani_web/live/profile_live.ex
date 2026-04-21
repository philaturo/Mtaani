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
      <div class="pscroll" id="mainScroll">
        <!-- COVER AREA -->
        <div class="cover-wrap">
          <div class="cover-img">
            <%= if @profile_user.cover_photo_url do %>
              <img src={@profile_user.cover_photo_url} class="w-full h-full object-cover" />
            <% end %>
            
            <div class="cover-pattern"></div>
            
            <div class="cover-top-actions">
              <button phx-click="navigate" phx-value-to="/home" class="cta-back">←</button>
              <div class="cta-right">
                <button class="cta-btn">🔍</button>
                <%= if @is_own_profile do %>
                  <button phx-click="open_edit_modal" class="cta-btn">✏️</button>
                <% end %>
                 <button class="cta-btn">⋯</button>
              </div>
            </div>
            
            <div class="cover-location-tag">
              <div class="clt-icon">📍</div>
              
              <div class="clt-text">Last seen: {@profile_user.location || "Nairobi, Kenya"}</div>
            </div>
            
            <%= if @is_own_profile do %>
              <button phx-click="upload_cover_photo" class="cover-edit-badge">📷 Edit cover</button>
            <% end %>
          </div>
        </div>
        
    <!-- AVATAR ROW -->
        <div class="avatar-row">
          <div class="av-wrap">
            <div class="av-circle" style={"background: #{@avatar_color}"}>
              <%= if @profile_user.profile_photo_url do %>
                <img
                  src={@profile_user.profile_photo_url}
                  class="w-full h-full rounded-full object-cover"
                />
              <% else %>
                {@avatar_initials}
              <% end %>
              
              <%= if @is_own_profile do %>
                <div class="av-edit">
                  <div class="av-edit-inner">📷</div>
                </div>
              <% end %>
            </div>
          </div>
          
          <div class="av-action-row">
            <%= if @is_own_profile do %>
              <button phx-click="open_edit_modal" class="av-btn primary">Edit profile</button>
            <% else %>
              <button
                phx-click={if @is_following, do: "unfollow_user", else: "follow_user"}
                class={if @is_following, do: "av-btn secondary", else: "av-btn primary"}
              >
                {if @is_following, do: "Following", else: "Follow"}
              </button>
            <% end %>
             <button phx-click="share_profile" class="av-btn secondary">Share</button>
            <button phx-click="open_chat" class="av-btn icon-btn">⋯</button>
          </div>
        </div>
        
    <!-- IDENTITY BLOCK -->
        <div class="identity">
          <div class="id-name-row">
            <div class="id-name">{@profile_user.name}</div>
            
            <%= if @profile_user.phone_verified do %>
              <div class="id-verified">✓</div>
            <% end %>
          </div>
          
          <div class="id-handle">@{@profile_user.username}</div>
          
          <div class="id-bio">{@profile_user.bio || "No bio yet"}</div>
          
          <div class="id-tags">
            <%= if @profile_user.traveler_type do %>
              <div class="id-tag" style="background:#ecfdf5;color:#065f46">
                🎒 {@profile_user.traveler_type}
              </div>
            <% end %>
            
            <%= for vibe <- (@profile_user.travel_vibes || []) |> Enum.take(3) do %>
              <div
                class="id-tag"
                style="background:var(--color-background-secondary);color:var(--color-text-secondary)"
              >
                {vibe}
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- IDENTITY SIGNAL STRIP -->
        <div class="identity-signals">
          <div class="is-badge-row">
            <%= if @profile_user.phone_verified do %>
              <div class="is-badge is-badge-verified">
                <div class="isb-icon">✓</div>
                 <span>Verified member</span>
              </div>
            <% end %>
            
            <%= if @profile_user.traveler_type do %>
              <div class="is-badge is-badge-traveler">
                <div class="isb-icon">🎒</div>
                 <span>{@profile_user.traveler_type}</span>
              </div>
            <% end %>
            
            <%= if (@stats.posts_count || 0) > 20 or (@stats.trips_count || 0) > 10 do %>
              <div class="is-badge is-badge-contributor">
                <div class="isb-icon">⭐</div>
                 <span>Top contributor</span>
              </div>
            <% end %>
          </div>
          
          <div class="is-meta-line">
            <div class="is-meta-item">
              <div class="is-meta-dot" style="background:#10b981"></div>
               <span>Phone verified</span>
            </div>
            
            <div class="is-meta-sep">·</div>
            
            <div class="is-meta-item">
              <span>Member since {Calendar.strftime(@profile_user.inserted_at, "%b %Y")}</span>
            </div>
          </div>
        </div>
        
    <!-- STAT STRIP -->
        <div class="stat-strip">
          <div class="ss-item">
            <div class="ss-val">{@stats.trips_count}</div>
            
            <div class="ss-label">Trips</div>
            
            <div class="ss-sub">completed</div>
          </div>
          
          <div class="ss-item">
            <div class="ss-val">{@stats.counties_count}</div>
            
            <div class="ss-label">Counties</div>
            
            <div class="ss-sub">of 47</div>
          </div>
          
          <div class="ss-item">
            <div class="ss-val">{@stats.buddies_count}</div>
            
            <div class="ss-label">Buddies</div>
            
            <div class="ss-sub">connected</div>
          </div>
          
          <div class="ss-item">
            <div class="ss-val">{@stats.followers_count}</div>
            
            <div class="ss-label">Followers</div>
            
            <div class="ss-sub">following {@stats.following_count}</div>
          </div>
        </div>
        
    <!-- TAB NAVIGATION -->
        <div class="tab-nav">
          <button
            phx-click="switch_tab"
            phx-value-tab="posts"
            class={["tab", @active_tab == "posts" && "on"]}
          >
            Posts
          </button>
          
          <button
            phx-click="switch_tab"
            phx-value-tab="places"
            class={["tab", @active_tab == "places" && "on"]}
          >
            Places
          </button>
          
          <button
            phx-click="switch_tab"
            phx-value-tab="photos"
            class={["tab", @active_tab == "photos" && "on"]}
          >
            Photos
          </button>
          
          <button
            phx-click="switch_tab"
            phx-value-tab="dna"
            class={["tab", @active_tab == "dna" && "on"]}
          >
            Travel DNA
          </button>
          
          <button
            phx-click="switch_tab"
            phx-value-tab="buddies"
            class={["tab", @active_tab == "buddies" && "on"]}
          >
            Buddies
          </button>
        </div>
        
    <!-- POSTS PANEL -->
        <div class={["panel", @active_tab == "posts" && "show"]}>
          <div class="posts-panel">
            <%= if @is_own_profile do %>
              <div class="make-post-bar">
                <div class="mpb-av">{@avatar_initials}</div>
                
                <div class="mpb-input">What's on your mind, {@profile_user.name}?</div>
                
                <div class="mpb-icons">
                  <div class="mpb-icon">📷</div>
                  
                  <div class="mpb-icon">📍</div>
                </div>
              </div>
            <% end %>
            
            <%= for post <- @posts do %>
              <div class="post-card">
                <div class="pc-header">
                  <div class="pch-av">{get_initials(post.user.name)}</div>
                  
                  <div class="pch-info">
                    <div class="pch-name">{post.user.name}</div>
                    
                    <div class="pch-time">{time_ago(post.inserted_at)}</div>
                  </div>
                  
                  <div class="pch-more">⋯</div>
                </div>
                
                <div class="pc-body">{post.content}</div>
                
                <div class="pc-reactions">
                  <div class="prc">❤️ {post.likes_count}</div>
                  
                  <div class="prc">💬 {post.comments_count}</div>
                  
                  <div class="prc">🔁 {post.reposts_count}</div>
                </div>
                
                <div class="pc-actions">
                  <div class="pca">❤️ Like</div>
                  
                  <div class="pca">💬 Comment</div>
                  
                  <div class="pca">🔁 Repost</div>
                </div>
              </div>
            <% end %>
            
            <%= if @posts == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No posts yet</div>
            <% end %>
          </div>
        </div>
        
    <!-- PLACES PANEL -->
        <div class={["panel", @active_tab == "places" && "show"]}>
          <div class="places-panel">
            <div class="county-strip">
              <div class="cs-map">🗺️</div>
              
              <div class="cs-body">
                <div class="cs-title">Kenya Explorer Progress</div>
                
                <div class="cs-track">
                  <div class="cs-fill" style={"width: #{(@stats.counties_count / 47) * 100}%"}></div>
                </div>
                
                <div class="cs-sub">
                  {@stats.counties_count} of 47 counties visited · Earn "Kenya Explorer" at 30
                </div>
              </div>
              
              <div class="cs-count">{@stats.counties_count}</div>
            </div>
            
            <div class="sec-head">
              <div class="sec-title">Recent visits</div>
              
              <div class="sec-action">See all</div>
            </div>
            
            <div class="place-grid">
              <%= for visit <- Enum.take(@visited_places, 4) do %>
                <div class="pl-card">
                  <div class="pl-img" style="background:#d1fae5">
                    🦁<div class="pl-badge" style="background:#ecfdf5;color:#065f46">Visited</div>
                  </div>
                  
                  <div class="pl-body">
                    <div class="pl-name">{visit.place_name || "Place"}</div>
                    
                    <div class="pl-meta">{visit.county || "Kenya"}</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- PHOTOS PANEL -->
        <div class={["panel", @active_tab == "photos" && "show"]}>
          <div class="photos-panel">
            <div class="sec-head">
              <div class="sec-title">Albums</div>
              
              <div class="sec-action">New album</div>
            </div>
            
            <div class="photo-album-row">
              <%= for album <- @albums do %>
                <div class="album-card">
                  <div class="ac-img" style="background:#d1fae5">🦁</div>
                  
                  <div class="ac-body">
                    <div class="ac-name">{album.name}</div>
                    
                    <div class="ac-count">{length(album.photos)} photos</div>
                  </div>
                </div>
              <% end %>
            </div>
            
            <div class="sec-head">
              <div class="sec-title">All photos · {length(@recent_photos)}</div>
              
              <div class="sec-action">Add photo</div>
            </div>
            
            <div class="photo-grid-3">
              <%= for photo <- Enum.take(@recent_photos, 9) do %>
                <div class="pg3-item" style="background:#d1fae5">
                  <img src={photo.url} class="w-full h-full object-cover" />
                </div>
              <% end %>
            </div>
            
            <%= if @recent_photos == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No photos yet</div>
            <% end %>
          </div>
        </div>
        
    <!-- TRAVEL DNA PANEL -->
        <div class={["panel", @active_tab == "dna" && "show"]}>
          <div class="dna-panel">
            <!-- Trust Breakdown Card -->
            <div class="trust-breakdown-card">
              <div class="tbc-header">
                <div class="tbc-left">
                  <div
                    class="tbc-avatar-ring"
                    style={"background: conic-gradient(#10b981 0deg #{@trust.arc_deg}deg, var(--color-border-tertiary) #{@trust.arc_deg}deg 360deg)"}
                  >
                    <div class="tbc-avatar-inner">{@avatar_initials}</div>
                  </div>
                  
                  <div class="tbc-title-group">
                    <div class="tbc-label">Community standing</div>
                    
                    <div class="tbc-level">{@trust.level}</div>
                  </div>
                </div>
                
                <div class="tbc-pct-wrap">
                  <svg class="tbc-ring-svg" viewBox="0 0 44 44">
                    <circle class="tbc-ring-bg" cx="22" cy="22" r="18" /><circle
                      class="tbc-ring-fill"
                      cx="22"
                      cy="22"
                      r="18"
                      stroke-dasharray="113.1"
                      stroke-dashoffset={@trust.stroke_dashoffset}
                    />
                  </svg>
                  
                  <div class="tbc-pct-label">{@trust.score}%</div>
                </div>
              </div>
              
              <div class="tbc-signals">
                <%= for signal <- @trust.signals do %>
                  <div class={[
                    "tbc-signal",
                    signal.completed && "done",
                    !signal.completed && "pending"
                  ]}>
                    <div class={["tbc-signal-icon", !signal.completed && "tbc-icon-pending"]}>
                      {if signal.completed, do: "✓", else: "○"}
                    </div>
                    
                    <div class="tbc-signal-body">
                      <div class="tbc-signal-name">
                        {case signal.key do
                          :phone_verified -> "Phone verified"
                          :profile_complete -> "Profile complete"
                          :trips_completed -> "Trips completed"
                          :community_active -> "Active community member"
                          :trips_led -> "Led group trips"
                          :id_verified -> "ID verification"
                        end}
                      </div>
                      
                      <div class="tbc-signal-sub">
                        {signal.description || "+#{signal.points} pts"}
                      </div>
                    </div>
                    
                    <div class={["tbc-signal-pts", !signal.completed && "tbc-pts-pending"]}>
                      +{signal.points}
                    </div>
                  </div>
                <% end %>
              </div>
              
              <div class="tbc-next">
                <div class="tbc-next-label">
                  Next level: <strong>{@trust.next_level}</strong> at {@trust.next_threshold}%
                </div>
                
                <div class="tbc-next-track">
                  <div class="tbc-next-fill" style={"width: #{@trust.score}%"}></div>
                </div>
                
                <div class="tbc-next-sub">{@trust.points_needed} points to next level</div>
              </div>
            </div>
            
    <!-- Travel DNA Details -->
            <div class="dna-card">
              <div class="dna-section">
                <div class="dna-label">TRAVELER TYPE</div>
                
                <div class="dna-value">🎒 {@profile_user.traveler_type || "Traveler"}</div>
              </div>
              
              <div class="dna-divider"></div>
              
              <div class="dna-section">
                <div class="dna-label">TRAVEL STYLE</div>
                
                <div class="dna-tags">
                  <%= for vibe <- @profile_user.travel_vibes || [] do %>
                    <div class="dna-tag" style="background:#ecfdf5;color:#065f46">{vibe}</div>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Travel Badges -->
            <div class="sec-head">
              <div class="sec-title">Travel badges</div>
              
              <div class="sec-action">See all</div>
            </div>
            
            <div class="badges-scroll">
              <%= for user_badge <- @badges do %>
                <% badge = user_badge.badge %>
                <div class="badge-card">
                  <div class="badge-icon-wrap" style="background:#ecfdf5">{badge.icon || "🏅"}</div>
                  
                  <div class="badge-name">{badge.name}</div>
                  
                  <div class="badge-desc">{badge.description}</div>
                </div>
              <% end %>
            </div>
            
    <!-- About Section -->
            <div class="dna-card">
              <div class="text-[11px] font-medium text-[var(--color-text-secondary)] uppercase tracking-wide mb-2">
                ABOUT
              </div>
              
              <%= if @profile_user.location do %>
                <div class="info-row">
                  <div class="ir-icon" style="background:#ecfdf5">📍</div>
                  
                  <div class="ir-body">
                    <div class="ir-label">Location</div>
                    
                    <div class="ir-value">{@profile_user.location}</div>
                  </div>
                </div>
              <% end %>
              
              <div class="info-row">
                <div class="ir-icon" style="background:#eff6ff">📅</div>
                
                <div class="ir-body">
                  <div class="ir-label">Member since</div>
                  
                  <div class="ir-value">{Calendar.strftime(@profile_user.inserted_at, "%B %Y")}</div>
                </div>
              </div>
              
              <%= if @profile_user.website do %>
                <div class="info-row">
                  <div class="ir-icon" style="background:#fdf4ff">🌐</div>
                  
                  <div class="ir-body">
                    <div class="ir-label">Website</div>
                    
                    <div class="ir-value" style="color:#3b82f6">{@profile_user.website}</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
    <!-- BUDDIES PANEL -->
        <div class={["panel", @active_tab == "buddies" && "show"]}>
          <div class="buddies-panel">
            <div class="sec-head">
              <div class="sec-title">Suggested travel buddies</div>
              
              <div class="sec-action">See all</div>
            </div>
            
            <div class="suggested-strip">
              <%= for buddy <- @suggested_buddies do %>
                <div class="sug-card">
                  <div class="sc-av" style={"background: #{get_avatar_color(buddy.id)}"}>
                    {get_initials(buddy.name)}
                  </div>
                  
                  <div class="sc-name">{buddy.name}</div>
                  
                  <div class="sc-sub">{buddy.traveler_type || "Traveler"}</div>
                   <button phx-click="follow_user" class="sc-btn">Connect</button>
                </div>
              <% end %>
            </div>
            
            <div class="sec-head">
              <div class="sec-title">Your travel buddies · {@stats.buddies_count}</div>
              
              <div class="sec-action">Find more</div>
            </div>
            
            <%= for buddy <- @connected_buddies do %>
              <div class="buddy-row">
                <div class="br-av" style={"background: #{get_avatar_color(buddy.id)}"}>
                  {get_initials(buddy.name)}
                  <div class="br-online"></div>
                </div>
                
                <div class="br-body">
                  <div class="br-name">{buddy.name}</div>
                  
                  <div class="br-sub">{buddy.location || "Kenya"}</div>
                </div>
                 <button class="br-btn connected">Connected</button>
              </div>
            <% end %>
            
            <%= if @connected_buddies == [] do %>
              <div class="text-center py-8 text-[var(--color-text-secondary)]">No buddies yet</div>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- EDIT PROFILE MODAL -->
      <div class={["modal-bg", @edit_modal_open && "open"]} phx-click="close_edit_modal">
        <div class="edit-sheet" phx-click="preventDefault">
          <div class="es-handle"></div>
          
          <div class="es-topbar">
            <div class="es-title">Edit profile</div>
             <button type="button" phx-click="close_edit_modal" class="es-save">Save</button>
          </div>
          
          <div class="es-cover-edit">
            <div class="es-cover-cta">📷 Change cover photo</div>
            
            <div class="es-av-edit">
              {@avatar_initials}
              <div class="es-av-badge">📷</div>
            </div>
          </div>
          
          <form phx-submit="update_profile" class="es-body">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">
              <div class="es-field">
                <div class="ef-label">Name</div>
                
                <input type="text" name="profile[name]" value={@profile_user.name} class="ef-input" />
              </div>
            </div>
            
            <div class="es-field">
              <div class="ef-label">Username</div>
              
              <input
                type="text"
                name="profile[username]"
                value={"@" <> @profile_user.username}
                disabled
                class="ef-input opacity-70"
              />
            </div>
            
            <div class="es-field">
              <div class="ef-label">Bio</div>
               <textarea name="profile[bio]" rows="3" class="ef-input ef-textarea"><%= @profile_user.bio || "" %></textarea>
              <div class="ef-char">{String.length(@profile_user.bio || "")} / 160</div>
            </div>
            
            <div class="es-field">
              <div class="ef-label">Location</div>
              
              <input
                type="text"
                name="profile[location]"
                value={@profile_user.location || ""}
                class="ef-input"
              />
            </div>
            
            <div class="es-field">
              <div class="ef-label">Website</div>
              
              <input
                type="text"
                name="profile[website]"
                value={@profile_user.website || ""}
                class="ef-input"
              />
            </div>
            
            <div class="es-field">
              <div class="ef-label">Traveler type</div>
              
              <select name="profile[traveler_type]" class="ef-input">
                <option value="Traveler" selected={@profile_user.traveler_type == "Traveler"}>
                  🎒 Traveler
                </option>
                
                <option value="Local guide" selected={@profile_user.traveler_type == "Local guide"}>
                  🧭 Local guide
                </option>
                
                <option
                  value="Local resident"
                  selected={@profile_user.traveler_type == "Local resident"}
                >
                  🏡 Local resident
                </option>
                
                <option value="Business" selected={@profile_user.traveler_type == "Business"}>
                  🏢 Business
                </option>
              </select>
            </div>
            
            <div class="es-field">
              <div class="ef-label">Travel vibes (comma separated)</div>
              
              <input
                type="text"
                name="profile[travel_vibes]"
                value={Enum.join(@profile_user.travel_vibes || [], ", ")}
                class="ef-input"
              />
            </div>
            
            <div class="es-section-label">PRIVACY SETTINGS</div>
            
            <div class="es-privacy-row">
              <div class="epr-info">
                <div class="epr-label">Public profile</div>
                
                <div class="epr-sub">Anyone can view your trips and photos</div>
              </div>
              
              <button type="button" class={["toggle", @profile_user.is_private && "on"]}>
                <div class={[
                  "w-4 h-4 rounded-full bg-white shadow-sm transition-transform mt-0.5",
                  @profile_user.is_private && "translate-x-5",
                  !@profile_user.is_private && "translate-x-0.5"
                ]}>
                </div>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
