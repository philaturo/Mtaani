defmodule MtaaniWeb.HomeLive do
  use MtaaniWeb, :live_view
  
  alias Mtaani.AI
  alias Mtaani.Social.Post
  alias Mtaani.Accounts.User
  import Ecto.Query

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["user_id"] || 1
    current_user = Mtaani.Repo.get(User, current_user_id)
    
    # Load real feed posts
    posts = load_feed_posts()
    
    socket =
      socket
      |> assign(:active_tab, "home")
      |> assign(:show_emergency, false)
      |> assign(:current_user_id, current_user_id)
      |> assign(:current_user, current_user || %{name: "Explorer"})
      |> assign(:posts, posts)
      |> assign(:messages, [])
      |> assign(:input_text, "")
      |> assign(:thinking, false)
      |> assign(:user_location, nil)
      |> assign(:new_post_content, "")
      |> assign(:show_new_post_modal, false)
      |> assign(:stories, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "feed_updates")
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
      send(self(), :request_location)
    end

    {:ok, socket}
  end

  # Load real posts from database
  defp load_feed_posts do
    query = from post in Post,
      order_by: [desc: post.inserted_at],
      limit: 20,
      preload: [:user]
    
    Mtaani.Repo.all(query)
  end

  @impl true
  def handle_info(:request_location, socket) do
    {:noreply, push_event(socket, "request-geolocation", %{})}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  # Real-time feed updates
  @impl true
  def handle_info({:new_post, post}, socket) do
    posts = [post | socket.assigns.posts]
    {:noreply, assign(socket, :posts, posts)}
  end

  # AI Response Handler
  @impl true
  def handle_info({:ai_response, user_message}, socket) do
    user_id = socket.assigns.current_user_id
    location = socket.assigns.user_location
    
    case AI.chat(user_message, user_id, location) do
  {:ok, response} ->
    messages = socket.assigns.messages ++ [%{role: :assistant, content: response, timestamp: DateTime.utc_now()}]
    {:noreply, assign(socket, [messages: messages, thinking: false])}
  end
 end

  # Load more posts for infinite scroll
  @impl true
  def handle_event("load_more", %{"page" => page}, socket) do
    page_num = String.to_integer(page)
    offset = (page_num - 1) * 10
    
    query = from post in Post,
      order_by: [desc: post.inserted_at],
      limit: 10,
      offset: ^offset,
      preload: [:user]
    
    new_posts = Mtaani.Repo.all(query)
    all_posts = socket.assigns.posts ++ new_posts
    has_more = length(new_posts) == 10
    
    {:reply, %{has_more: has_more}, assign(socket, :posts, all_posts)}
  end

  # Feed interactions
  @impl true
  def handle_event("like_post", %{"post_id" => _post_id}, socket) do
    # TODO: Implement like functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_new_post_modal", _, socket) do
    {:noreply, assign(socket, :show_new_post_modal, true)}
  end

  @impl true
  def handle_event("close_new_post_modal", _, socket) do
    {:noreply, assign(socket, [show_new_post_modal: false, new_post_content: ""])}
  end

  @impl true
  def handle_event("update_new_post", %{"content" => content}, socket) do
    {:noreply, assign(socket, :new_post_content, content)}
  end

  @impl true
  def handle_event("create_post", _, socket) do
    content = socket.assigns.new_post_content
    
    if String.trim(content) != "" do
      attrs = %{
        content: content,
        user_id: socket.assigns.current_user_id
      }
      
      case Mtaani.Social.create_post(attrs) do
        {:ok, post} ->
          Phoenix.PubSub.broadcast(Mtaani.PubSub, "feed_updates", {:new_post, post})
          {:noreply, assign(socket, [show_new_post_modal: false, new_post_content: ""])}
        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Quick action buttons (for AI)
  @impl true
  def handle_event("quick_action", %{"message" => message}, socket) do
    messages = socket.assigns.messages ++ [%{role: :user, content: message, timestamp: DateTime.utc_now()}]
    socket = assign(socket, [messages: messages, thinking: true])
    send(self(), {:ai_response, message})
    {:noreply, socket}
  end

  # Navigation
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  # Location handlers
  @impl true
  def handle_event("location-update", %{"lat" => lat, "lng" => lng}, socket) do
    {:noreply, assign(socket, :user_location, %{lat: lat, lng: lng})}
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

  # AI Chat handlers
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

  # Toggle chat (JS handles the UI)
  @impl true
  def handle_event("toggle_chat", _, socket) do
    {:noreply, socket}
  end

  # Online tracking
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

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, push_navigate(socket, to: "/logout")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-gradient-to-b from-onyx/5 to-white">
      <!-- Stories Bar -->
      <div class="stories-container overflow-x-auto px-4 py-3 border-b border-onyx-mauve/10">
        <div class="flex gap-3">
          <!-- Add Story Button -->
          <div class="flex-shrink-0 text-center cursor-pointer">
            <div class="w-16 h-16 rounded-full bg-gradient-to-tr from-verdant-sage to-verdant-forest p-0.5">
              <div class="w-full h-full rounded-full bg-white flex items-center justify-center">
                <svg class="w-6 h-6 text-verdant-forest" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
              </div>
            </div>
            <p class="text-xs text-onyx-deep mt-1">Your Story</p>
          </div>
        </div>
      </div>

      <!-- Main Feed with Infinite Scroll -->
      <div id="feed-scroll" phx-hook="InfiniteScroll" class="flex-1 overflow-y-auto custom-scrollbar">
        <!-- Create Post Box -->
        <div class="bg-white rounded-xl shadow-sm p-4 m-4 border border-onyx-mauve/10">
          <div class="flex gap-3">
            <div class="w-10 h-10 rounded-full bg-verdant-forest/20 flex items-center justify-center">
              <span class="text-verdant-forest font-semibold"><%= String.slice(@current_user.name, 0..0) %></span>
            </div>
            <button phx-click="show_new_post_modal" class="flex-1 text-left px-4 py-2 rounded-full bg-gray-100 text-onyx-mauve hover:bg-gray-200 transition-colors">
              What's on your mind, <%= @current_user.name %>?
            </button>
          </div>
          <div class="flex justify-around mt-3 pt-3 border-t border-gray-100">
            <button class="flex items-center gap-2 text-sm text-onyx-mauve hover:text-verdant-forest transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span>Photo</span>
            </button>
            <button class="flex items-center gap-2 text-sm text-onyx-mauve hover:text-verdant-forest transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Feeling</span>
            </button>
          </div>
        </div>

        <!-- Feed Posts -->
        <div id="feed-container" phx-hook="FeedAnimations" class="space-y-4 px-4 pb-20">
          <%= for post <- @posts do %>
            <div class="feed-post bg-white rounded-xl shadow-sm border border-onyx-mauve/10 overflow-hidden">
              <!-- Post Header -->
              <div class="p-4 flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-full bg-verdant-forest/20 flex items-center justify-center">
                    <span class="text-verdant-forest font-semibold"><%= if post.user, do: String.slice(post.user.name, 0..0), else: "?" %></span>
                  </div>
                  <div>
                    <p class="font-semibold text-onyx-deep"><%= if post.user, do: post.user.name, else: "Unknown User" %></p>
                    <p class="text-xs text-onyx-mauve"><%= time_ago(post.inserted_at) %></p>
                  </div>
                </div>
                <button class="text-onyx-mauve hover:text-onyx-deep">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
                  </svg>
                </button>
              </div>
              
              <!-- Post Content -->
              <div class="px-4 pb-3">
                <p class="text-onyx-deep"><%= post.content %></p>
              </div>
              
              <!-- Post Actions -->
              <div class="px-4 py-2 border-t border-gray-100 flex">
                <button phx-click="like_post" phx-value-post_id={post.id} class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve hover:text-verdant-forest transition-colors post-action-btn">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                  <span>Like</span>
                </button>
                <button class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve hover:text-verdant-forest transition-colors post-action-btn">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                  <span>Comment</span>
                </button>
                <button class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve hover:text-verdant-forest transition-colors post-action-btn">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                  </svg>
                  <span>Share</span>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Floating Chat Button -->
      <div id="chat-toggle" phx-hook="ChatToggle" class="fixed bottom-20 right-4 z-50">
        <button class="bg-verdant-forest text-white p-4 rounded-full shadow-lg hover:bg-verdant-deep transition-all hover:scale-110">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
          </svg>
        </button>
      </div>

      <!-- New Post Modal -->
      <div :if={@show_new_post_modal} class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-xl max-w-md w-full modal-content">
          <div class="p-4 border-b flex justify-between items-center">
            <h3 class="text-lg font-semibold">Create Post</h3>
            <button phx-click="close_new_post_modal" class="text-onyx-mauve hover:text-onyx-deep">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div class="p-4">
            <textarea phx-change="update_new_post" phx-debounce="300" value={@new_post_content} placeholder="What's on your mind?" class="w-full h-32 p-3 border rounded-lg resize-none focus:outline-none focus:border-verdant-forest"></textarea>
          </div>
          <div class="p-4 border-t flex justify-end">
            <button phx-click="create_post" class="bg-verdant-forest text-white px-6 py-2 rounded-full hover:bg-verdant-deep transition-colors">
              Post
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp time_ago(datetime) do
  now = DateTime.utc_now()
  
  # Convert NaiveDateTime to DateTime if needed
  datetime_to_compare = case datetime do
    %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
    %DateTime{} -> datetime
  end
  
  diff = DateTime.diff(now, datetime_to_compare)
  
  cond do
    diff < 60 -> "just now"
    diff < 3600 -> "#{div(diff, 60)}m"
    diff < 86400 -> "#{div(diff, 3600)}h"
    true -> Calendar.strftime(datetime_to_compare, "%b %d")
  end
end
end