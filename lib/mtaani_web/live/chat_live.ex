defmodule MtaaniWeb.ChatLive do
  use MtaaniWeb, :live_view
  import Ecto.Query

  alias Mtaani.Chat
  alias Mtaani.Chat.Message
  alias Mtaani.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    # Get user_id from session (string key from LiveView)
    user_id = session["user_id"]

    if is_nil(user_id) do
      # No session, redirect to auth
      {:ok, push_navigate(socket, to: "/auth")}
    else
      # Convert to integer (session stores as string)
      current_user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
      current_user = Mtaani.Repo.get(User, current_user_id)

      socket =
        socket
        |> assign(:active_tab, "chat")
        |> assign(:show_emergency, false)
        |> assign(:current_user_id, current_user_id)
        |> assign(:current_user, current_user)
        |> assign(:filter, "all")
        |> assign(:search_query, "")
        |> assign(:conversations, [])
        |> assign(:filtered_conversations, [])
        |> assign(:selected_conversation, nil)
        |> assign(:messages, [])
        |> assign(:grouped_messages, [])
        |> assign(:chat_id, nil)
        |> assign(:chat_type, nil)
        |> assign(:chat_partner, nil)
        |> assign(:input_text, "")
        |> assign(:online_users, [])
        |> assign(:typing_users, [])
        |> assign(:partner_safety_zone, %{name: "Unknown", safety_level: 2})
        |> assign(:partner_distance, nil)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "chat_updates")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "user_typing")
        send(self(), :load_conversations)
        send(self(), :load_online_users)
      end

      {:ok, socket}
    end
  end

  defp load_conversations(user_id) when is_integer(user_id) do
    user_conversations = Mtaani.Chat.list_user_conversations(user_id)

    Enum.map(user_conversations, fn cp ->
      conv = cp.conversation

      other_participant =
        if conv.type == "direct" do
          Enum.find(conv.participants, fn p -> p.user_id != user_id end)
        else
          nil
        end

      other_user =
        if other_participant do
          Mtaani.Repo.get(User, other_participant.user_id)
        end

      conv_name =
        cond do
          conv.type == "direct" and not is_nil(other_user) -> other_user.name
          not is_nil(conv.name) -> conv.name
          true -> "Chat"
        end

      avatar =
        cond do
          conv.type == "direct" and not is_nil(other_user) ->
            String.slice(other_user.name, 0..0) |> String.upcase()

          not is_nil(conv.name) ->
            String.slice(conv.name, 0..0) |> String.upcase()

          true ->
            "C"
        end

      last_msg =
        if not is_nil(conv.last_message) do
          conv.last_message
        else
          "No messages yet"
        end

      is_online =
        if other_user do
          MtaaniWeb.OnlineTracker.is_online?(other_user.id)
        else
          false
        end

      safety_zone =
        if other_user do
          get_safety_zone_for_user(other_user.id)
        else
          %{name: "Unknown", safety_level: 2}
        end

      %{
        id: conv.id,
        name: conv_name,
        avatar: avatar,
        last_message: last_msg,
        last_message_time: conv.last_message_at || conv.inserted_at,
        unread: Mtaani.Chat.get_unread_count(conv.id, user_id),
        online: is_online,
        safety_zone: safety_zone,
        type: conv.type,
        is_pinned: conv.is_pinned || false,
        participants: conv.participants
      }
    end)
  end

  defp load_conversations(_), do: []

  defp get_safety_zone_for_user(user_id) do
    user = Mtaani.Repo.get(User, user_id)

    if user && user.location do
      %{name: "Karen, Nairobi", safety_level: 1}
    else
      %{name: "Unknown", safety_level: 2}
    end
  end

  defp get_distance_between_users(_user1_id, _user2_id) do
    "2.4"
  end

  @impl true
  def handle_info(:load_conversations, socket) do
    conversations = load_conversations(socket.assigns.current_user_id)
    filtered = apply_filter(conversations, socket.assigns.filter, socket.assigns.search_query)
    {:noreply, assign(socket, conversations: conversations, filtered_conversations: filtered)}
  end

  @impl true
  def handle_info(:load_online_users, socket) do
    online_users = MtaaniWeb.OnlineTracker.get_online_users()
    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, assign(socket, :online_count, count)}
  end

  @impl true
  def handle_info({:message_read, message_id, reader_id}, socket) do
    {:noreply,
     push_event(socket, "message_read", %{message_id: message_id, reader_id: reader_id})}
  end

  @impl true
  def handle_info({:user_typing, chat_id, user_id, is_typing}, socket) do
    if socket.assigns.chat_id == chat_id do
      typing_users =
        if is_typing do
          [user_id | socket.assigns.typing_users] |> Enum.uniq()
        else
          Enum.reject(socket.assigns.typing_users, &(&1 == user_id))
        end

      {:noreply, assign(socket, :typing_users, typing_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    messages = socket.assigns.messages ++ [message]
    grouped = group_messages_by_date(messages)
    {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    filtered = apply_filter(socket.assigns.conversations, filter, socket.assigns.search_query)
    {:noreply, assign(socket, filter: filter, filtered_conversations: filtered)}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    filtered = apply_filter(socket.assigns.conversations, socket.assigns.filter, query)
    {:noreply, assign(socket, search_query: query, filtered_conversations: filtered)}
  end

  @impl true
  def handle_event("select_conversation", %{"id" => id}, socket) do
    conversation = Enum.find(socket.assigns.conversations, &(&1.id == String.to_integer(id)))
    messages = load_messages(String.to_integer(id))
    grouped = group_messages_by_date(messages)

    partner_id = get_partner_id(conversation, socket.assigns.current_user_id)
    partner = if partner_id, do: Mtaani.Repo.get(User, partner_id)

    safety_zone =
      if partner_id,
        do: get_safety_zone_for_user(partner_id),
        else: %{name: "Unknown", safety_level: 2}

    distance =
      if partner_id, do: get_distance_between_users(socket.assigns.current_user_id, partner_id)

    Phoenix.PubSub.subscribe(Mtaani.PubSub, "chat:#{id}")

    {:noreply,
     assign(socket,
       chat_id: String.to_integer(id),
       chat_type: conversation.type,
       chat_partner: partner,
       selected_conversation: conversation,
       messages: messages,
       grouped_messages: grouped,
       partner_safety_zone: safety_zone,
       partner_distance: distance
     )}
  end

  @impl true
  def handle_event("update-input", %{"message" => message}, socket) do
    if socket.assigns.chat_id do
      Phoenix.PubSub.broadcast(
        Mtaani.PubSub,
        "user_typing",
        {:user_typing, socket.assigns.chat_id, socket.assigns.current_user_id, message != ""}
      )
    end

    {:noreply, assign(socket, :input_text, message)}
  end

  @impl true
  def handle_event("send_message", %{"value" => message}, socket) do
    if String.trim(message) != "" and socket.assigns.chat_id do
      attrs = %{
        content: message,
        user_id: socket.assigns.current_user_id,
        conversation_id: socket.assigns.chat_id
      }

      case Mtaani.Chat.create_message(attrs) do
        {:ok, msg} ->
          messages = socket.assigns.messages ++ [msg]
          grouped = group_messages_by_date(messages)
          Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})

          {:noreply,
           assign(socket, messages: messages, grouped_messages: grouped, input_text: "")}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("mark_read", %{"message_id" => message_id}, socket) do
    Chat.mark_read(message_id, socket.assigns.current_user_id)
    {:noreply, socket}
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
  def handle_event("send_route", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("request_guide", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("meet_up", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("safety_check", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_new_message", _, socket) do
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
  def handle_event("user_online", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.add_user(user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("user_offline", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.remove_user(user_id)
    {:noreply, socket}
  end

  defp get_partner_id(conv, current_user_id) do
    if conv.type == "direct" do
      if Map.has_key?(conv, :participants) do
        other = Enum.find(conv.participants, fn p -> p.user_id != current_user_id end)
        other && other.user_id
      else
        nil
      end
    else
      nil
    end
  end

  defp is_user_online(user_id) do
    MtaaniWeb.OnlineTracker.is_online?(user_id)
  end

  defp load_messages(chat_id, limit \\ 50) do
    query =
      from(m in Message,
        where: m.conversation_id == ^chat_id,
        order_by: [asc: m.inserted_at],
        limit: ^limit,
        preload: [:user]
      )

    Mtaani.Repo.all(query)
  end

  defp apply_filter(conversations, filter, search_query) do
    conversations
    |> Enum.filter(fn conv ->
      cond do
        search_query != "" and
            not String.contains?(String.downcase(conv.name), String.downcase(search_query)) ->
          false

        filter == "unread" and conv.unread == 0 ->
          false

        filter == "favorites" and not conv.is_pinned ->
          false

        filter == "groups" and conv.type != "group" ->
          false

        filter == "nearby" ->
          false

        true ->
          true
      end
    end)
  end

  defp group_messages_by_date(messages) do
    messages
    |> Enum.group_by(fn msg -> DateTime.to_date(msg.inserted_at) end)
    |> Enum.sort_by(fn {date, _} -> date end, :desc)
    |> Enum.map(fn {date, msgs} ->
      {date, group_messages_by_sender(msgs)}
    end)
  end

  defp group_messages_by_sender(messages) do
    messages
    |> Enum.group_by(fn msg -> msg.user_id end)
    |> Enum.sort_by(fn {_, msgs} -> List.first(msgs).inserted_at end)
  end

  defp format_date_header(date) do
    today = DateTime.to_date(DateTime.utc_now())
    yesterday = Date.add(today, -1)

    cond do
      date == today -> "Today"
      date == yesterday -> "Yesterday"
      true -> Calendar.strftime(date, "%B %d, %Y")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="root">
      <div class="sidebar">
        <div class="sb-top">
          <div class="sb-title-row">
            <span class="sb-title">Messages</span>
            <div class="sb-icons">
              <button class="sb-icon" phx-click="show_new_message">✏️</button>
              <button class="sb-icon">⋯</button>
            </div>
          </div>
          
          <div class="search-bar">
            <span>🔍</span>
            <input
              type="text"
              placeholder="Search conversations..."
              value={@search_query}
              phx-change="search"
            />
          </div>
          
          <div class="filter-tabs">
            <button
              class={"ftab #{@filter == "all" && "active"}"}
              phx-click="set_filter"
              phx-value-filter="all"
            >
              All
            </button>
            
            <button
              class={"ftab #{@filter == "unread" && "active"}"}
              phx-click="set_filter"
              phx-value-filter="unread"
            >
              Unread
            </button>
            
            <button
              class={"ftab #{@filter == "groups" && "active"}"}
              phx-click="set_filter"
              phx-value-filter="groups"
            >
              Groups
            </button>
            
            <button
              class={"ftab #{@filter == "favorites" && "active"}"}
              phx-click="set_filter"
              phx-value-filter="favorites"
            >
              Favorites
            </button>
            
            <button
              class={"ftab #{@filter == "nearby" && "active"}"}
              phx-click="set_filter"
              phx-value-filter="nearby"
            >
              Nearby
            </button>
          </div>
        </div>
        
        <div style="padding: 0 14px; flex-shrink: 0;">
          <div class="active-strip">
            <%= for user <- @online_users do %>
              <div class="active-av-wrap" phx-click="select_conversation" phx-value-id={user.id}>
                <div class="active-ring">
                  <div class="active-av" style="background: #10b981;">
                    {String.slice(user.name, 0..1)}
                  </div>
                  
                  <div class="active-dot"></div>
                </div>
                
                <div class="active-name">{String.slice(user.name, 0..6)}</div>
              </div>
            <% end %>
          </div>
        </div>
        
        <div class="convo-list">
          <%= if Enum.any?(@filtered_conversations, & &1.is_pinned) do %>
            <div class="pin-label"><span class="pin-icon">📌</span> Pinned</div>
            
            <%= for conv <- Enum.filter(@filtered_conversations, & &1.is_pinned) do %>
              <div
                class={"convo-row #{@selected_conversation && @selected_conversation.id == conv.id && "active-chat"}"}
                phx-click="select_conversation"
                phx-value-id={conv.id}
              >
                <div class="convo-av-wrap">
                  <div class="convo-av" style="background: #10b981;">{conv.avatar}</div>
                  
                  <%= if conv.online do %>
                    <div class="convo-online"></div>
                  <% end %>
                </div>
                
                <div class="convo-body">
                  <div class="convo-top">
                    <div class="convo-name">{conv.name}</div>
                    
                    <div class="convo-time">{format_time(conv.last_message_time)}</div>
                  </div>
                  
                  <div class="convo-preview">
                    <%= if conv.unread > 0 do %>
                      <span class="tick blue">✓✓</span>
                    <% else %>
                      <span class="tick">✓✓</span>
                    <% end %>
                     {String.slice(conv.last_message, 0..40)}
                  </div>
                </div>
                
                <%= if conv.unread > 0 do %>
                  <div class="badge">{conv.unread}</div>
                <% end %>
                
                <div class={"safety-dot #{safety_dot_class(conv.safety_zone)}"}></div>
              </div>
            <% end %>
          <% end %>
          
          <div class="pin-label" style="margin-top: 4px;">Recent</div>
          
          <%= for conv <- Enum.reject(@filtered_conversations, & &1.is_pinned) do %>
            <div
              class={"convo-row #{@selected_conversation && @selected_conversation.id == conv.id && "active-chat"}"}
              phx-click="select_conversation"
              phx-value-id={conv.id}
            >
              <div class="convo-av-wrap">
                <div class="convo-av" style="background: #10b981;">{conv.avatar}</div>
                
                <%= if conv.online do %>
                  <div class="convo-online"></div>
                <% end %>
              </div>
              
              <div class="convo-body">
                <div class="convo-top">
                  <div class="convo-name">{conv.name}</div>
                  
                  <div class="convo-time">{format_time(conv.last_message_time)}</div>
                </div>
                
                <div class="convo-preview">
                  <%= if conv.unread > 0 do %>
                    <span class="tick blue">✓✓</span>
                  <% else %>
                    <span class="tick">✓✓</span>
                  <% end %>
                   {String.slice(conv.last_message, 0..40)}
                </div>
              </div>
              
              <%= if conv.unread > 0 do %>
                <div class="badge">{conv.unread}</div>
              <% end %>
              
              <div class={"safety-dot #{safety_dot_class(conv.safety_zone)}"}></div>
            </div>
          <% end %>
        </div>
      </div>
      
      <div class="main">
        <%= if @selected_conversation do %>
          <div class="chat-header">
            <div class="chat-header-av" style="background: #10b981;">
              {if @chat_partner, do: String.slice(@chat_partner.name, 0..1), else: "??"}
              <div class="chat-header-online"></div>
            </div>
            
            <div class="chat-header-info">
              <div class="chat-header-name">{@selected_conversation.name}</div>
              
              <div class="chat-header-sub">
                {if @chat_partner && is_user_online(@chat_partner.id), do: "Online", else: "Offline"} · {@partner_safety_zone.name}
              </div>
            </div>
            
            <div class="chat-header-actions">
              <button class="ch-btn">📞</button> <button class="ch-btn">🎥</button>
              <button class="ch-btn" phx-click="share_location">🗺️</button>
              <button class="ch-btn">⋯</button>
            </div>
          </div>
          
          <div class="travel-ctx">
            <div class="ctx-map">🗺️</div>
            
            <div class="ctx-info">
              <div class="ctx-title">
                {@chat_partner.name} is in {@partner_safety_zone.name} — {safety_zone_text(
                  @partner_safety_zone
                )}
              </div>
              
              <div class="ctx-sub">
                {if @partner_distance,
                  do: "#{@partner_distance} km from you",
                  else: "Location unknown"} · Last updated just now
              </div>
            </div>
            
            <div class="ctx-action">View on map</div>
          </div>
          
          <div class="messages" id="messages-container" phx-hook="ScrollToBottom">
            <%= for {date, sender_groups} <- @grouped_messages do %>
              <div class="day-divider">{format_date_header(date)}</div>
              
              <%= for {user_id, user_messages} <- sender_groups do %>
                <% is_me = user_id == @current_user_id %>
                <div class={"msg-group #{if is_me, do: "me", else: "them"}"}>
                  <div class="msg-with-av">
                    <%= if !is_me do %>
                      <% first_msg = List.first(user_messages) %>
                      <div class="msg-av" style="background: #3b82f6;">
                        {String.slice(first_msg.user.name, 0..1)}
                      </div>
                    <% end %>
                    
                    <div>
                      <%= for msg <- user_messages do %>
                        <div
                          class="bubble"
                          id={"message-#{msg.id}"}
                          phx-hook="MessageObserver"
                          data-message-id={msg.id}
                        >
                          {msg.content}
                          <div class="bubble-tail-info">
                            <span class="btime">{format_time_short(msg.inserted_at)}</span>
                            <%= if is_me do %>
                              <span class={"btick #{if msg.read_at, do: "read"}"}>✓✓</span>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
            
            <%= if @typing_users != [] do %>
              <div class="typing-indicator-container">
                <div class="typing-dots"><span></span><span></span><span></span></div>
                 <span>Someone is typing...</span>
              </div>
            <% end %>
          </div>
          
          <div class="quick-actions">
            <button class="qa" phx-click="share_location">📍 Share location</button>
            <button class="qa" phx-click="send_route">🗺️ Send route</button>
            <button class="qa" phx-click="request_guide">🧭 Request guide</button>
            <button class="qa" phx-click="meet_up">📅 Meet up</button>
            <button class="qa" phx-click="safety_check">🛡️ Safety check</button>
            <button class="qa danger" phx-click="sos_alert">🆘 SOS</button>
          </div>
          
          <div class="input-area">
            <div class="input-left">
              <button class="in-btn">📎</button> <button class="in-btn">📷</button>
            </div>
            
            <div class="msg-input-wrap">
              <input
                id="msgInput"
                type="text"
                placeholder={"Message #{@selected_conversation.name}..."}
                value={@input_text}
                phx-change="update-input"
                phx-keyup="send_message"
                phx-key="Enter"
              />
            </div>
            
            <button class="send-btn" phx-click="send_message" phx-value-message={@input_text}>
              ↑
            </button>
          </div>
        <% else %>
          <div class="no-chat-selected">
            <div class="no-chat-content">
              <div class="no-chat-icon">💬</div>
              
              <h3>Select a conversation</h3>
              
              <p>Choose a chat from the sidebar to start messaging</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime)

    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp format_time_short(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp safety_dot_class(safety_zone) do
    case safety_zone.safety_level do
      1 -> "safe"
      2 -> "caution"
      3 -> "danger"
      _ -> "safe"
    end
  end

  defp safety_zone_text(safety_zone) do
    case safety_zone.safety_level do
      1 -> "safe zone"
      2 -> "caution area"
      3 -> "high alert area"
      _ -> "unknown area"
    end
  end
end
