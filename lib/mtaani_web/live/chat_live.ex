defmodule MtaaniWeb.ChatLive do
  use MtaaniWeb, :live_view
  import Ecto.Query

  alias Mtaani.Chat
  alias Mtaani.Chat.Message
  alias Mtaani.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]

    if is_nil(user_id) do
      {:ok, push_navigate(socket, to: "/auth")}
    else
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
        |> assign(:partner_safety_zone, nil)
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
          nil
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
    # This should come from your actual safety zone data source
    # For now, return nil if no real data exists
    user = Mtaani.Repo.get(User, user_id)

    if user && user.location do
      # In real implementation, query actual safety zones from database
      nil
    else
      nil
    end
  end

  defp get_distance_between_users(_user1_id, _user2_id) do
    # This should calculate real distance from user locations
    # Return nil if locations aren't available
    nil
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
        else: nil

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

  # Complete implementation of missing handlers
  @impl true
  def handle_event("share_location", _, socket) do
    {:noreply, push_event(socket, "get_location", %{})}
  end

  @impl true
  def handle_event("location_shared", %{"lat" => lat, "lng" => lng}, socket) do
    location_text = "📍 Shared location: https://maps.google.com/?q=#{lat},#{lng}"

    attrs = %{
      content: location_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "location",
      media_url: "https://maps.google.com/?q=#{lat},#{lng}"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})
        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to share location")}
    end
  end

  @impl true
  def handle_event("send_route", _, socket) do
    {:noreply, push_event(socket, "show_route_modal", %{})}
  end

  @impl true
  def handle_event("route_selected", %{"from" => from, "to" => to}, socket) do
    route_text = "🗺️ Route from #{from} to #{to}"

    attrs = %{
      content: route_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "route"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})
        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("request_guide", _, socket) do
    guide_text = "🧭 Guide request: Looking for a local guide"

    attrs = %{
      content: guide_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "guide_request"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})
        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("meet_up", _, socket) do
    {:noreply, push_event(socket, "show_meetup_modal", %{})}
  end

  @impl true
  def handle_event("meetup_scheduled", %{"location" => location, "time" => time}, socket) do
    meetup_text = "📅 Meetup scheduled: #{location} at #{time}"

    attrs = %{
      content: meetup_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "meetup"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})
        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("safety_check", _, socket) do
    check_text = "🛡️ Safety check: I'm safe"

    attrs = %{
      content: check_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "safety_check"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})
        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("sos_alert", _, socket) do
    {:noreply, push_event(socket, "get_location_for_sos", %{})}
  end

  @impl true
  def handle_event("sos_triggered", %{"lat" => lat, "lng" => lng}, socket) do
    sos_text =
      "🆘 SOS ALERT! Need immediate assistance at: https://maps.google.com/?q=#{lat},#{lng}"

    attrs = %{
      content: sos_text,
      user_id: socket.assigns.current_user_id,
      conversation_id: socket.assigns.chat_id,
      media_type: "sos"
    }

    case Mtaani.Chat.create_message(attrs) do
      {:ok, msg} ->
        messages = socket.assigns.messages ++ [msg]
        grouped = group_messages_by_date(messages)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "chat_updates", {:new_message, msg})

        # Broadcast to SOS system if it exists
        Phoenix.PubSub.broadcast(
          Mtaani.PubSub,
          "sos_alerts",
          {:sos_triggered,
           %{
             user_id: socket.assigns.current_user_id,
             user_name: socket.assigns.current_user.name,
             location: %{lat: lat, lng: lng},
             timestamp: DateTime.utc_now()
           }}
        )

        {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_back", _, socket) do
    {:noreply,
     assign(socket, selected_conversation: nil, chat_id: nil, messages: [], grouped_messages: [])}
  end

  @impl true
  def handle_event("open_profile", _, socket) do
    {:noreply, push_event(socket, "open_profile_drawer", %{})}
  end

  @impl true
  def handle_event("open_filter", _, socket) do
    {:noreply, push_event(socket, "open_filter_drawer", %{})}
  end

  @impl true
  def handle_event("close_filter", _, socket) do
    {:noreply, push_event(socket, "close_filter_drawer", %{})}
  end

  @impl true
  def handle_event("close_profile", _, socket) do
    {:noreply, push_event(socket, "close_profile_drawer", %{})}
  end

  @impl true
  def handle_event("stop_propagation", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_new_message", _, socket) do
    {:noreply, push_event(socket, "show_new_message_modal", %{})}
  end

  @impl true
  def handle_event("start_conversation", %{"user_id" => user_id}, socket) do
    case Chat.get_or_create_direct_conversation(
           socket.assigns.current_user_id,
           String.to_integer(user_id)
         ) do
      {:ok, conversation} ->
        send(self(), :load_conversations)
        {:noreply, push_event(socket, "select_conversation", %{"id" => conversation.id})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not start conversation")}
    end
  end

  @impl true
  def handle_event("add_reaction", %{"message_id" => message_id, "reaction" => reaction}, socket) do
    message = Mtaani.Repo.get(Message, message_id)

    if message do
      reactions = message.reactions || %{}
      user_reaction = Map.get(reactions, to_string(socket.assigns.current_user_id))

      updated_reactions =
        cond do
          user_reaction == reaction ->
            Map.delete(reactions, to_string(socket.assigns.current_user_id))

          true ->
            Map.put(reactions, to_string(socket.assigns.current_user_id), reaction)
        end

      message
      |> Message.changeset(%{reactions: updated_reactions})
      |> Mtaani.Repo.update()

      messages = load_messages(socket.assigns.chat_id)
      grouped = group_messages_by_date(messages)
      {:noreply, assign(socket, messages: messages, grouped_messages: grouped)}
    else
      {:noreply, socket}
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

  defp total_unread(conversations) do
    total = Enum.sum(Enum.map(conversations, & &1.unread))
    if total > 99, do: "99+", else: total
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
    case safety_zone do
      %{safety_level: 1} -> "safe"
      %{safety_level: 2} -> "caution"
      %{safety_level: 3} -> "danger"
      nil -> "hidden"
      _ -> "hidden"
    end
  end

  defp safety_zone_text(safety_zone) do
    case safety_zone do
      %{safety_level: 1} -> "safe zone"
      %{safety_level: 2} -> "caution area"
      %{safety_level: 3} -> "high alert area"
      _ -> nil
    end
  end
end
