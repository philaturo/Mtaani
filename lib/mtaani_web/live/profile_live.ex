defmodule MtaaniWeb.ProfileLive do
  use MtaaniWeb, :live_view
  alias Mtaani.Repo
  alias Mtaani.Accounts.User
  alias Mtaani.Social.Friendship
  alias Mtaani.Social.UserPhoto

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    # Load profile by username (or current user if viewing own)
    user = Repo.get_by(User, username: username) || Repo.get(User, socket.assigns.current_user_id)
    friends = get_friends(user)
    photos = get_recent_photos(user)
    
    socket =
      socket
      |> assign(:active_tab, "profile")
      |> assign(:user, user)
      |> assign(:friends, friends)
      |> assign(:photos, photos)
      |> assign(:active_section, "profile") # profile, photos, albums
      |> assign(:show_edit_modal, false)
      |> assign(:show_photo_modal, false)

    {:ok, socket}
  end

  # Add these placeholder functions
  defp get_friends(user) do
    # TODO: Implement friend fetching
    []
  end

  defp get_recent_photos(user) do
    # TODO: Implement photo fetching
    []
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20 bg-onyx min-h-screen">
      <!-- Cover Photo -->
      <div class="relative h-48 md:h-64 bg-gradient-to-r from-verdant-forest to-verdant-sage">
        <img :if={@user.cover_photo_url} src={@user.cover_photo_url} class="w-full h-full object-cover" />
        <button class="absolute bottom-4 right-4 bg-black/50 hover:bg-black/70 text-white rounded-full p-2 backdrop-blur-sm">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z" />
          </svg>
        </button>
      </div>

      <!-- Profile Info Section -->
      <div class="relative px-4">
        <!-- Profile Photo with Camera Icon -->
        <div class="relative -mt-16 mb-4">
          <div class="relative inline-block">
            <div class="w-28 h-28 rounded-full border-4 border-white bg-white overflow-hidden">
              <img :if={@user.profile_photo_url} src={@user.profile_photo_url} class="w-full h-full object-cover" />
              <div :if={!@user.profile_photo_url} class="w-full h-full bg-verdant-forest/20 flex items-center justify-center">
                <span class="text-4xl text-verdant-forest font-semibold"><%= String.slice(@user.name, 0, 1) |> String.upcase() %></span>
              </div>
            </div>
            <!-- Camera Icon for Upload -->
            <button phx-click="show_photo_upload" class="absolute bottom-0 right-0 bg-verdant-forest text-white rounded-full p-1.5 border-2 border-white hover:bg-verdant-deep">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z" />
              </svg>
            </button>
          </div>
          
          <!-- User Name and Actions -->
          <div class="flex flex-wrap justify-between items-start mt-2">
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-onyx-deep"><%= @user.name %></h1>
              <p class="text-onyx-mauve text-sm"><%= @user.bio || "Traveler exploring Kenya" %></p>
            </div>
            <div class="flex gap-2 mt-2 sm:mt-0">
              <button phx-click="edit_profile" class="px-4 py-1.5 bg-onyx-mauve/10 rounded-full text-sm text-onyx-deep hover:bg-onyx-mauve/20">
                Edit Profile
              </button>
              <button phx-click="toggle_lock" class="px-4 py-1.5 bg-onyx-mauve/10 rounded-full text-sm text-onyx-deep hover:bg-onyx-mauve/20">
                <i class="fas fa-lock"></i>
              </button>
            </div>
          </div>
        </div>

        <!-- Friends Section with Mini Avatars -->
        <div class="mb-6">
          <div class="flex justify-between items-center mb-3">
            <h2 class="text-lg font-semibold text-onyx-deep">Friends</h2>
            <button phx-click="view_all_friends" class="text-sm text-verdant-forest hover:underline">
              See All Friends
            </button>
          </div>
          <div class="flex -space-x-2">
            <%= for friend <- Enum.take(@friends, 5) do %>
              <div class="w-10 h-10 rounded-full border-2 border-white bg-verdant-forest/10 overflow-hidden">
                <img :if={friend.profile_photo_url} src={friend.profile_photo_url} class="w-full h-full object-cover" />
                <div :if={!friend.profile_photo_url} class="w-full h-full flex items-center justify-center">
                  <span class="text-sm font-medium text-verdant-forest"><%= String.slice(friend.name, 0, 1) |> String.upcase() %></span>
                </div>
              </div>
            <% end %>
            <%= if length(@friends) > 5 do %>
              <div class="w-10 h-10 rounded-full bg-onyx-mauve/20 flex items-center justify-center text-xs text-onyx-deep font-medium border-2 border-white">
                +<%= length(@friends) - 5 %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Tab Navigation -->
        <div class="border-b border-onyx-mauve/20 mb-4">
          <div class="flex gap-6">
            <button phx-click="set_section" phx-value-section="profile" class={[
              "pb-3 text-sm font-medium transition-colors",
              @active_section == "profile" && "text-verdant-forest border-b-2 border-verdant-forest",
              @active_section != "profile" && "text-onyx-mauve hover:text-onyx-deep"
            ]}>
              Profile
            </button>
            <button phx-click="set_section" phx-value-section="photos" class={[
              "pb-3 text-sm font-medium transition-colors",
              @active_section == "photos" && "text-verdant-forest border-b-2 border-verdant-forest",
              @active_section != "photos" && "text-onyx-mauve hover:text-onyx-deep"
            ]}>
              Photos
            </button>
            <button phx-click="set_section" phx-value-section="albums" class={[
              "pb-3 text-sm font-medium transition-colors",
              @active_section == "albums" && "text-verdant-forest border-b-2 border-verdant-forest",
              @active_section != "albums" && "text-onyx-mauve hover:text-onyx-deep"
            ]}>
              Albums
            </button>
          </div>
        </div>

        <!-- Section Content -->
        <div class="pb-6">
          <!-- Profile Section -->
          <div :if={@active_section == "profile"} class="space-y-4">
            <div class="bg-white rounded-xl border border-onyx-mauve/20 p-4">
              <h3 class="font-medium text-onyx-deep mb-3">About</h3>
              <div class="space-y-2 text-sm">
                <p><span class="text-onyx-mauve">Location:</span> <span class="text-onyx-deep"><%= @user.location || "Nairobi, Kenya" %></span></p>
                <p><span class="text-onyx-mauve">Member since:</span> <span class="text-onyx-deep"><%= Calendar.strftime(@user.inserted_at, "%B %Y") %></span></p>
                <p><span class="text-onyx-mauve">Friends:</span> <span class="text-onyx-deep"><%= @user.friends_count %></span></p>
              </div>
            </div>
          </div>

          <!-- Photos Section -->
          <div :if={@active_section == "photos"}>
            <div class="grid grid-cols-3 gap-1">
              <%= for photo <- @photos do %>
                <div class="aspect-square overflow-hidden">
                  <img src={photo.thumbnail_url || photo.url} class="w-full h-full object-cover" />
                </div>
              <% end %>
            </div>
          </div>

          <!-- Albums Section -->
          <div :if={@active_section == "albums"} class="space-y-3">
            <p class="text-onyx-mauve text-center py-8">No albums created yet</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Photo Upload Modal -->
    <%= if @show_photo_modal do %>
      <div class="fixed inset-0 bg-onyx-deep/50 flex items-center justify-center z-50">
        <div class="bg-white rounded-2xl p-6 max-w-md w-full mx-4">
          <h2 class="text-xl font-semibold text-onyx-deep mb-4">Update Profile Photo</h2>
          <div class="space-y-3">
            <button class="w-full py-3 bg-verdant-forest text-white rounded-xl hover:bg-verdant-deep">
              Take Photo
            </button>
            <button class="w-full py-3 border border-verdant-forest text-verdant-forest rounded-xl hover:bg-verdant-forest/5">
              Choose from Gallery
            </button>
            <button phx-click="close_photo_modal" class="w-full py-3 text-onyx-mauve hover:bg-onyx-mauve/5 rounded-xl">
              Cancel
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end