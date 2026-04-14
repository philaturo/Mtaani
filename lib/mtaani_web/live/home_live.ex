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

    socket =
      socket
      |> assign(:active_tab, "home")
      |> assign(:show_emergency, false)
      |> assign(:current_user_id, current_user_id)
      |> assign(:current_user, current_user || %{name: "Explorer"})
      |> assign(:posts, [])
      |> assign(:pending_posts, [])
      |> assign(:loading_posts, true)
      |> assign(:messages, [])
      |> assign(:input_text, "")
      |> assign(:thinking, false)
      |> assign(:user_location, nil)
      |> assign(:new_post_content, "")
      |> assign(:show_new_post_modal, false)
      |> assign(:stories, [])
      |> assign(:typing_users, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "feed_updates")
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
      send(self(), :request_location)
      send(self(), :load_posts)
    end

    {:ok, socket}
  end

  defp load_feed_posts do
    query =
      from(post in Post,
        order_by: [desc: post.inserted_at],
        limit: 20,
        preload: [:user]
      )

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

  @impl true
  def handle_info(:load_posts, socket) do
    # Add delay to see skeletons (remove after testing)
    Process.sleep(2000)
    posts = load_feed_posts()
    {:noreply, assign(socket, posts: posts, loading_posts: false)}
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    posts = [post | socket.assigns.posts]
    {:noreply, assign(socket, :posts, posts)}
  end

  @impl true
  def handle_info({:ai_response, user_message}, socket) do
    user_id = socket.assigns.current_user_id
    location = socket.assigns.user_location

    case AI.chat(user_message, user_id, location) do
      {:ok, response} ->
        messages =
          socket.assigns.messages ++
            [%{role: :assistant, content: response, timestamp: DateTime.utc_now()}]

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(:thinking, false)
         |> push_event("ai_response", %{message: response})}
    end
  end

  # Optimistic update: save post in background
  @impl true
  def handle_info({:save_post, content, temp_id}, socket) do
    attrs = %{
      content: content,
      user_id: socket.assigns.current_user_id
    }

    case Mtaani.Social.create_post(attrs) do
      {:ok, post} ->
        pending_posts = Enum.reject(socket.assigns.pending_posts, &(&1.id == temp_id))
        posts = [post | socket.assigns.posts]
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "feed_updates", {:new_post, post})
        {:noreply, assign(socket, posts: posts, pending_posts: pending_posts)}

      {:error, _changeset} ->
        pending_posts =
          Enum.map(socket.assigns.pending_posts, fn
            %{id: ^temp_id} = pending -> %{pending | failed: true}
            other -> other
          end)

        {:noreply, assign(socket, pending_posts: pending_posts)}
    end
  end

  # AI context refresh (preserves conversation memory)
  @impl true
  def handle_info({:refresh_ai_context, location}, socket) do
    {:noreply, assign(socket, :user_location, location)}
  end

  @impl true
  def handle_event("quick_action", %{"message" => message}, socket) do
    messages =
      socket.assigns.messages ++ [%{role: :user, content: message, timestamp: DateTime.utc_now()}]

    socket = assign(socket, messages: messages, thinking: true)
    send(self(), {:ai_response, message})
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", %{"page" => page}, socket) do
    page_num = if is_binary(page), do: String.to_integer(page), else: page
    offset = (page_num - 1) * 10

    query =
      from(post in Post,
        order_by: [desc: post.inserted_at],
        limit: 10,
        offset: ^offset,
        preload: [:user]
      )

    new_posts = Mtaani.Repo.all(query)
    all_posts = socket.assigns.posts ++ new_posts
    has_more = length(new_posts) == 10

    {:reply, %{has_more: has_more}, assign(socket, :posts, all_posts)}
  end

  @impl true
  def handle_event("like_post", %{"post_id" => _post_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_new_post_modal", _, socket) do
    {:noreply, assign(socket, :show_new_post_modal, true)}
  end

  @impl true
  def handle_event("close_new_post_modal", _, socket) do
    {:noreply, assign(socket, show_new_post_modal: false, new_post_content: "")}
  end

  @impl true
  def handle_event("update_new_post", %{"content" => content}, socket) do
    {:noreply, assign(socket, :new_post_content, content)}
  end

  # Optimistic update: create post immediately
  @impl true
  def handle_event("create_post", %{"content" => content}, socket) do
    if String.trim(content) != "" do
      temp_id = :erlang.unique_integer([:positive])

      temp_post = %{
        id: temp_id,
        content: content,
        user_id: socket.assigns.current_user_id,
        user: socket.assigns.current_user,
        inserted_at: DateTime.utc_now(),
        pending: true,
        # ADD THIS LINE
        failed: false
      }

      pending_posts = [temp_post | socket.assigns.pending_posts]

      socket =
        assign(socket,
          pending_posts: pending_posts,
          new_post_content: "",
          show_new_post_modal: false
        )

      send(self(), {:save_post, content, temp_id})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Retry failed post
  @impl true
  def handle_event("retry_post", %{"temp_id" => temp_id}, socket) do
    temp_id_int = String.to_integer(temp_id)

    case Enum.find(socket.assigns.pending_posts, &(&1.id == temp_id_int)) do
      %{content: content} ->
        pending_posts =
          Enum.map(socket.assigns.pending_posts, fn
            %{id: ^temp_id_int} = pending -> %{pending | retrying: true, failed: false}
            other -> other
          end)

        socket = assign(socket, pending_posts: pending_posts)
        send(self(), {:save_post, content, temp_id_int})
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  # Delete pending/failed post
  @impl true
  def handle_event("delete_pending_post", %{"temp_id" => temp_id}, socket) do
    temp_id_int = String.to_integer(temp_id)
    pending_posts = Enum.reject(socket.assigns.pending_posts, &(&1.id == temp_id_int))
    {:noreply, assign(socket, pending_posts: pending_posts)}
  end

  # Pull-to-refresh handler
  @impl true
  def handle_event("refresh_feed", _, socket) do
    posts = load_feed_posts()

    if socket.assigns.user_location do
      send(self(), {:refresh_ai_context, socket.assigns.user_location})
    end

    {:reply, %{}, assign(socket, posts: posts, loading_posts: false)}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

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

  @impl true
  def handle_event("update-input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_text, message)}
  end

  @impl true
  def handle_event("send-message", %{"message" => message}, socket) when message != "" do
    messages =
      socket.assigns.messages ++ [%{role: :user, content: message, timestamp: DateTime.utc_now()}]

    socket = assign(socket, messages: messages, thinking: true, input_text: "")
    send(self(), {:ai_response, message})
    {:noreply, socket}
  end

  @impl true
  def handle_event("send-message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_chat", _, socket) do
    {:noreply, socket}
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

  # Add reaction to post
  @impl true
  def handle_event("add_reaction", %{"type" => "post", "id" => post_id, "emoji" => emoji}, socket) do
    post_id_int = String.to_integer(post_id)
    user_id = socket.assigns.current_user_id

    case Mtaani.Social.add_reaction(user_id, post_id_int, emoji) do
      {:ok, _reaction} ->
        posts = load_feed_posts()
        {:noreply, assign(socket, :posts, posts)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  # Remove reaction from post
  @impl true
  def handle_event("remove_reaction", %{"post_id" => post_id, "emoji" => emoji}, socket) do
    post_id_int = String.to_integer(post_id)
    user_id = socket.assigns.current_user_id

    case Mtaani.Social.remove_reaction(user_id, post_id_int, emoji) do
      {:ok, _reaction} ->
        posts = load_feed_posts()
        {:noreply, assign(socket, :posts, posts)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  # Typing indicator handlers
  @impl true
  def handle_event("user_typing", %{"type" => "feed", "id" => _post_id}, socket) do
    user = socket.assigns.current_user
    current_typing = socket.assigns.typing_users

    if !Enum.any?(current_typing, &(&1.id == user.id)) do
      {:noreply, assign(socket, :typing_users, current_typing ++ [user])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("user_stopped_typing", %{"type" => "feed", "id" => _post_id}, socket) do
    user = socket.assigns.current_user
    current_typing = socket.assigns.typing_users
    {:noreply, assign(socket, :typing_users, Enum.reject(current_typing, &(&1.id == user.id)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-gradient-to-b from-onyx/5 to-white">
      
    <!-- Stories Bar -->
      <div class="stories-container overflow-x-auto px-4 py-3 border-b border-onyx-mauve/10">
        <div class="flex gap-3">
          <div class="flex-shrink-0 text-center cursor-pointer">
            <div class="w-16 h-16 rounded-full bg-gradient-to-tr from-verdant-sage to-verdant-forest p-0.5">
              <div class="w-full h-full rounded-full bg-white flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-verdant-forest"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 4v16m8-8H4"
                  />
                </svg>
              </div>
            </div>
            
            <p class="text-xs text-onyx-deep mt-1">Your Story</p>
          </div>
        </div>
      </div>
      
    <!-- Main Feed with Pull-to-Refresh -->
      <div id="feed-scroll" phx-hook="PullToRefresh" class="flex-1 overflow-y-auto custom-scrollbar">
        
    <!-- Create Post Button -->
        <div class="bg-white rounded-xl shadow-sm p-4 m-4 border border-onyx-mauve/10">
          <div class="flex gap-3">
            <div class="w-10 h-10 rounded-full bg-verdant-forest/20 flex items-center justify-center">
              <span class="text-verdant-forest font-semibold">
                {String.slice(@current_user.name, 0..0)}
              </span>
            </div>
            
            <button
              phx-click="show_new_post_modal"
              class="flex-1 text-left px-4 py-2 rounded-full bg-gray-100 text-onyx-mauve hover:bg-gray-200 transition-colors"
            >
              What's on your mind, {@current_user.name}?
            </button>
          </div>
          
          <div class="flex justify-around mt-3 pt-3 border-t border-gray-100">
            <button class="flex items-center gap-2 text-sm text-onyx-mauve hover:text-verdant-forest transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
               <span>Photo</span>
            </button>
            
            <button class="flex items-center gap-2 text-sm text-onyx-mauve hover:text-verdant-forest transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
               <span>Feeling</span>
            </button>
          </div>
        </div>
        
    <!-- Feed Container -->
        <div id="feed-container" phx-hook="FeedAnimations" class="space-y-4 px-4 pb-20">
          
    <!-- Loading Skeletons -->
          <%= if @loading_posts do %>
            <%= for _ <- 1..3 do %>
              <div class="animate-pulse bg-white rounded-xl shadow-sm border border-onyx-mauve/10 overflow-hidden">
                <div class="p-4 flex items-center gap-3">
                  <div class="w-10 h-10 rounded-full bg-gray-200 dark:bg-gray-700"></div>
                  
                  <div class="flex-1">
                    <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-32 mb-2"></div>
                    
                    <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-20"></div>
                  </div>
                </div>
                
                <div class="px-4 pb-3 space-y-2">
                  <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-full"></div>
                  
                  <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4"></div>
                  
                  <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>
                </div>
                
                <div class="px-4 py-2 border-t border-gray-100 flex">
                  <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
                  
                  <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
                  
                  <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
                </div>
              </div>
            <% end %>
          <% else %>
            
    <!-- Pending Posts (Optimistic Updates) -->
            <%= for pending <- @pending_posts do %>
              <div class="feed-post bg-white rounded-xl shadow-sm border border-onyx-mauve/10 overflow-hidden opacity-90">
                <div class="p-4 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-full bg-verdant-forest/20 flex items-center justify-center">
                      <span class="text-verdant-forest font-semibold">
                        {String.slice(pending.user.name, 0..0)}
                      </span>
                    </div>
                    
                    <div>
                      <p class="font-semibold text-onyx-deep">{pending.user.name}</p>
                      
                      <p class="text-xs text-onyx-mauve">just now</p>
                    </div>
                  </div>
                  
                  <button class="text-onyx-mauve hover:text-onyx-deep">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
                      />
                    </svg>
                  </button>
                </div>
                
                <div class="px-4 pb-3">
                  <p class="text-onyx-deep">{pending.content}</p>
                </div>
                
                <div class="px-4 pb-2">
                  <%= if pending.failed do %>
                    <div class="flex items-center gap-2 text-red-500 text-sm">
                      <span>Failed to post</span>
                      <button
                        phx-click="retry_post"
                        phx-value-temp_id={pending.id}
                        class="text-verdant-forest underline"
                      >
                        Retry
                      </button>
                      
                      <button
                        phx-click="delete_pending_post"
                        phx-value-temp_id={pending.id}
                        class="text-onyx-mauve underline"
                      >
                        Discard
                      </button>
                    </div>
                  <% else %>
                    <div class="flex items-center gap-2 text-onyx-mauve text-sm">
                      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle
                          class="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          stroke-width="4"
                        >
                        </circle>
                        
                        <path
                          class="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        >
                        </path>
                      </svg>
                       <span>Sending...</span>
                    </div>
                  <% end %>
                </div>
                
                <div class="px-4 py-2 border-t border-gray-100 flex">
                  <button class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve opacity-50">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
                      />
                    </svg>
                     <span>Like</span>
                  </button>
                  
                  <button class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve opacity-50">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                      />
                    </svg>
                     <span>Comment</span>
                  </button>
                  
                  <button class="flex-1 flex items-center justify-center gap-2 py-2 text-onyx-mauve opacity-50">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"
                      />
                    </svg>
                     <span>Share</span>
                  </button>
                </div>
              </div>
            <% end %>
            
    <!-- Real Posts -->
            <%= for post <- @posts do %>
              <div
                id={"post-container-#{post.id}"}
                phx-hook="DoubleTapLike"
                data-post-id={post.id}
                class="feed-post bg-white rounded-xl shadow-sm border border-onyx-mauve/10 overflow-hidden"
              >
                <!-- Post Header -->
                <div class="p-4 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-full bg-verdant-forest/20 flex items-center justify-center">
                      <span class="text-verdant-forest font-semibold">
                        {if post.user, do: String.slice(post.user.name, 0..0), else: "?"}
                      </span>
                    </div>
                    
                    <div>
                      <p class="font-semibold text-onyx-deep">
                        {if post.user, do: post.user.name, else: "Unknown User"}
                      </p>
                      
                      <p class="text-xs text-onyx-mauve">{time_ago(post.inserted_at)}</p>
                    </div>
                  </div>
                  
                  <button class="text-onyx-mauve hover:text-onyx-deep">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
                      />
                    </svg>
                  </button>
                </div>
                
    <!-- Post Content -->
                <div class="px-4 pb-3">
                  <p class="text-onyx-deep">{post.content}</p>
                </div>
                
    <!-- Comment Section (hidden initially) -->
                <div id={"comment-section-#{post.id}"} class="hidden comment-section">
                  <div class="px-4 pb-3">
                    <div class="flex gap-2">
                      <input
                        type="text"
                        placeholder="Write a comment..."
                        class="flex-1 px-4 py-2 rounded-full bg-gray-100 dark:bg-gray-800 focus:outline-none focus:ring-1 focus:ring-verdant-forest"
                      />
                      <button class="send-comment bg-verdant-forest text-white rounded-full px-4 py-2 text-sm hover:bg-verdant-deep transition-colors">
                        Post
                      </button>
                    </div>
                  </div>
                </div>
                
    <!-- Typing Indicator -->
                <%= if @typing_users != [] do %>
                  <div class="px-4 py-2">
                    <div class="flex items-center gap-2">
                      <div class="flex -space-x-1">
                        <%= for typing_user <- Enum.take(@typing_users, 3) do %>
                          <div class="w-6 h-6 rounded-full bg-verdant-forest/20 flex items-center justify-center text-xs">
                            {String.slice(typing_user.name, 0..0)}
                          </div>
                        <% end %>
                      </div>
                      
                      <p class="text-sm text-onyx-mauve">
                        <%= if length(@typing_users) == 1 do %>
                          {List.first(@typing_users).name} is typing
                        <% else %>
                          {length(@typing_users)} people are typing
                        <% end %>
                      </p>
                      
                      <div class="flex gap-0.5">
                        <span
                          class="w-1 h-1 bg-verdant-forest rounded-full animate-bounce"
                          style="animation-delay: 0s"
                        >
                        </span>
                        <span
                          class="w-1 h-1 bg-verdant-forest rounded-full animate-bounce"
                          style="animation-delay: 0.2s"
                        >
                        </span>
                        <span
                          class="w-1 h-1 bg-verdant-forest rounded-full animate-bounce"
                          style="animation-delay: 0.4s"
                        >
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
                
    <!-- Action Buttons -->
                <div class="px-4 py-2 flex justify-evenly items-center">
                  <!-- Comment Button -->
                  <button
                    class="comment-button flex flex-col items-center gap-1 text-onyx-mauve hover:text-verdant-forest transition-colors group"
                    data-post-id={post.id}
                  >
                    <svg
                      class="w-5 h-5 group-hover:scale-110 transition-transform"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                      />
                    </svg>
                     <span class="text-xs">{post.comments_count || 0}</span>
                  </button>
                  
    <!-- Repost Button -->
                  <button class="flex flex-col items-center gap-1 text-onyx-mauve hover:text-verdant-sage transition-colors group">
                    <svg
                      class="w-5 h-5 group-hover:scale-110 transition-transform"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"
                      />
                    </svg>
                     <span class="text-xs">{post.reposts_count || 0}</span>
                  </button>
                  
    <!-- Like Button -->
                  <button
                    id={"like-btn-#{post.id}"}
                    phx-click="like_post"
                    phx-value-post_id={post.id}
                    class="like-button flex flex-col items-center gap-1 text-onyx-mauve transition-colors group"
                    phx-hook="LikeAnimation"
                  >
                    <svg
                      class="w-5 h-5 group-hover:scale-110 transition-transform group-hover:text-red-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
                      />
                    </svg>
                     <span class="like-count text-xs">{post.likes_count || 0}</span>
                  </button>
                  
    <!-- Share Button -->
                  <button class="flex flex-col items-center gap-1 text-onyx-mauve hover:text-verdant-forest transition-colors group">
                    <svg
                      class="w-5 h-5 group-hover:scale-110 transition-transform"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                      />
                    </svg>
                     <span class="text-xs">Share</span>
                  </button>
                  
    <!-- Bookmark Button -->
                  <button class="flex flex-col items-center gap-1 text-onyx-mauve hover:text-verdant-forest transition-colors group">
                    <svg
                      class="w-5 h-5 group-hover:scale-110 transition-transform"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="1.5"
                        d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z"
                      />
                    </svg>
                     <span class="text-xs">Save</span>
                  </button>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      
    <!-- Floating Chat Button -->
      <div id="chat-toggle" phx-hook="ChatToggle" class="fixed bottom-20 right-4 z-50">
        <button class="bg-verdant-forest text-white p-4 rounded-full shadow-lg hover:bg-verdant-deep transition-all hover:scale-110">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
            />
          </svg>
        </button>
      </div>
      
    <!-- Create Post Modal -->
      <div
        :if={@show_new_post_modal}
        id="new-post-modal"
        class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      >
        <div class="bg-white rounded-xl max-w-md w-full modal-content">
          
    <!-- Modal Header -->
          <div class="p-4 border-b flex justify-between items-center">
            <h3 class="text-lg font-semibold">Create Post</h3>
            
            <button phx-click="close_new_post_modal" class="text-onyx-mauve hover:text-onyx-deep">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          
    <!-- Form -->
          <form phx-submit="create_post" phx-change="update_new_post">
            <div class="p-4">
              <textarea
                name="content"
                value={@new_post_content}
                placeholder="What's on your mind?"
                class="w-full h-32 p-3 border rounded-lg resize-none focus:outline-none focus:border-verdant-forest"
              ><%= @new_post_content %></textarea>
            </div>
            
            <div class="p-4 border-t flex justify-end">
              <button
                type="submit"
                class="bg-verdant-forest text-white px-6 py-2 rounded-full hover:bg-verdant-deep transition-colors"
              >
                Post
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get reaction counts for a post
  defp get_reaction_counts(post_id) do
    Mtaani.Social.get_reaction_counts_for_post(post_id)
  end

  # Helper function to format time ago (e.g., "5m ago", "2h ago")
  defp time_ago(datetime) do
    now = DateTime.utc_now()

    datetime_to_compare =
      case datetime do
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
