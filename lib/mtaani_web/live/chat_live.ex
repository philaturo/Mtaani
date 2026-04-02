defmodule MtaaniWeb.ChatLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, "chat")
      |> assign(:show_emergency, false)
      |> assign(:filter, "all") # all, unread, favorites
      |> assign(:search_query, "")
      |> assign(:conversations, get_conversations())
      |> assign(:selected_conversation, nil)
      |> assign(:messages, [])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20 h-full flex flex-col">
      <!-- Header with Search -->
      <div class="bg-white border-b border-onyx-mauve/20 px-4 py-3">
        <div class="flex justify-between items-center mb-3">
          <h1 class="text-xl font-semibold text-onyx-deep">Chats</h1>
          <button class="text-verdant-forest">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
          </button>
        </div>
        
        <!-- Search Bar -->
        <div class="relative">
          <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-onyx-mauve" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input
            type="text"
            placeholder="Ask Mtaani or Search"
            value={@search_query}
            phx-change="search"
            class="w-full bg-onyx-mauve/5 border border-onyx-mauve/20 rounded-full py-2 pl-10 pr-4 text-onyx-deep placeholder-onyx-mauve focus:outline-none focus:border-verdant-forest"
          />
        </div>
      </div>

      <!-- Filter Tabs -->
      <div class="flex border-b border-onyx-mauve/20 px-4">
        <button phx-click="set_filter" phx-value-filter="all" class={[
          "flex-1 py-3 text-sm font-medium transition-colors",
          @filter == "all" && "text-verdant-forest border-b-2 border-verdant-forest",
          @filter != "all" && "text-onyx-mauve hover:text-onyx-deep"
        ]}>
          All Chats
        </button>
        <button phx-click="set_filter" phx-value-filter="unread" class={[
          "flex-1 py-3 text-sm font-medium transition-colors",
          @filter == "unread" && "text-verdant-forest border-b-2 border-verdant-forest",
          @filter != "unread" && "text-onyx-mauve hover:text-onyx-deep"
        ]}>
          Unread
        </button>
        <button phx-click="set_filter" phx-value-filter="favorites" class={[
          "flex-1 py-3 text-sm font-medium transition-colors",
          @filter == "favorites" && "text-verdant-forest border-b-2 border-verdant-forest",
          @filter != "favorites" && "text-onyx-mauve hover:text-onyx-deep"
        ]}>
          Favorites
        </button>
      </div>

      <!-- Conversations List -->
      <div class="flex-1 overflow-y-auto">
        <%= for conv <- @conversations do %>
          <button
            phx-click="select_conversation"
            phx-value-id={conv.id}
            class="w-full p-4 border-b border-onyx-mauve/10 hover:bg-onyx-mauve/5 transition-colors"
          >
            <div class="flex items-center gap-3">
              <div class="relative">
                <div class="w-12 h-12 rounded-full bg-verdant-forest/10 flex items-center justify-center">
                  <span class="text-verdant-forest font-semibold"><%= conv.name |> String.slice(0, 1) |> String.upcase() %></span>
                </div>
                <%= if conv.online do %>
                  <span class="absolute bottom-0 right-0 w-3 h-3 bg-verdant-sage rounded-full border-2 border-white"></span>
                <% end %>
              </div>
              <div class="flex-1">
                <div class="flex justify-between items-baseline">
                  <h3 class="font-medium text-onyx-deep"><%= conv.name %></h3>
                  <span class="text-xs text-onyx-mauve"><%= conv.time %></span>
                </div>
                <p class="text-sm text-onyx-mauve truncate">
                  <%= if conv.unread > 0 do %>
                    <span class="font-medium text-verdant-forest"><%= conv.unread %> new messages</span>
                  <% else %>
                    <%= conv.last_message %>
                  <% end %>
                </p>
              </div>
              <%= if conv.unread > 0 do %>
                <div class="w-5 h-5 bg-verdant-forest rounded-full flex items-center justify-center">
                  <span class="text-xs text-white"><%= conv.unread %></span>
                </div>
              <% end %>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_conversations do
    # Fetch conversations from database
    []
  end

  # Navigation handlers
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, push_navigate(socket, to: "/logout")}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("select_conversation", %{"id" => _id}, socket) do
  # This will be implemented when we add conversation functionality
  # The underscore tells Elixir this variable is intentionally unused
  {:noreply, socket}
end

  # Emergency handlers
  @impl true
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end

  # Online tracker handlers
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
end