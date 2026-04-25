defmodule MtaaniWeb.GroupsLive do
  use MtaaniWeb, :live_view

  alias Mtaani.Groups
  alias Mtaani.Groups.Group
  alias Mtaani.Accounts

  # ==================== MOUNT ====================

  @impl true
  def mount(_params, session, socket) do
    # Get user_id from session parameter (not socket.assigns)
    user_id = session["user_id"]

    if user_id do
      current_user = Accounts.get_user(user_id)

      if current_user do
        # Load all necessary data
        pulse_data = Groups.get_pulse_data(current_user.id)
        user_groups = Groups.list_user_groups(current_user.id)

        suggested_groups =
          Groups.list_groups(%{joined_by_user_id: nil, for_user_id: current_user.id})

        socket =
          socket
          |> assign(:current_user, current_user)
          |> assign(:loading, true)
          # For bottom nav highlight
          |> assign(:active_tab, "groups")
          |> assign(:page_title, "Groups")
          |> assign(:screen, :list)
          |> assign(:filter, "all")
          |> assign(:user_groups, user_groups)
          |> assign(:suggested_groups, suggested_groups)
          |> assign(:display_groups, user_groups)
          |> assign(:pulse_data, pulse_data)
          |> assign(:selected_group, nil)
          |> assign(:active_channel, "chat")
          |> assign(:group_messages, [])
          |> assign(:safety_messages, [])
          |> assign(:group_photos, [])
          |> assign(:photos_count, 0)
          |> assign(:group_events, [])
          |> assign(:active_convoy, nil)
          |> assign(:convoy_stats, nil)
          |> assign(:convoy_updates, [])
          |> assign(:sharing_count, 0)
          |> assign(:is_sharing_location, false)
          |> assign(:convoy_distance, "?")
          |> assign(:convoy_eta, "?")
          |> assign(:pinned_message, nil)
          |> assign(:typing_users, [])
          |> assign(:show_create_modal, false)
          |> assign(:new_group, %Group{type: "trip"})
          |> assign(:input_text, "")
          |> assign(:statuses, [])

        # Load data asynchronously (non-blocking)
        send(self(), :load_groups_data)

        # Subscribe to real-time updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Mtaani.PubSub, "groups_updates")
          Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
          Phoenix.PubSub.subscribe(Mtaani.PubSub, "new_message")
          Phoenix.PubSub.subscribe(Mtaani.PubSub, "convoy_updates")
        end

        {:ok, socket,
         temporary_assigns: [
           group_messages: [],
           safety_messages: [],
           group_photos: [],
           group_events: [],
           convoy_updates: []
         ]}
      else
        {:ok, redirect(socket, to: "/login")}
      end
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  # ==================== REAL-TIME HANDLERS ====================

  @impl true
  def handle_info(:load_groups_data, socket) do
    current_user = socket.assigns.current_user

    # Load all data in background
    pulse_data = Groups.get_pulse_data(current_user.id)
    user_groups = Groups.list_user_groups(current_user.id)
    suggested_groups = Groups.list_groups(%{joined_by_user_id: nil, for_user_id: current_user.id})

    # Update socket with loaded data and turn off loading
    socket =
      socket
      |> assign(:pulse_data, pulse_data)
      |> assign(:user_groups, user_groups)
      |> assign(:suggested_groups, suggested_groups)
      |> assign(:display_groups, user_groups)
      # Skeletons disappear
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.selected_group && message.group_id == socket.assigns.selected_group.id do
      channel_name = get_channel_name_from_id(message.channel_id)

      cond do
        socket.assigns.active_channel == "chat" and channel_name == "general" ->
          {:noreply, assign(socket, :group_messages, [message | socket.assigns.group_messages])}

        socket.assigns.active_channel == "safety" and channel_name == "safety" ->
          {:noreply, assign(socket, :safety_messages, [message | socket.assigns.safety_messages])}

        true ->
          {:noreply, socket}
      end
    else
      groups = update_group_preview(socket.assigns.user_groups, message)
      {:noreply, assign(socket, :user_groups, groups)}
    end
  end

  @impl true
  def handle_info({:convoy_update, update}, socket) do
    if socket.assigns.active_convoy && update.convoy_id == socket.assigns.active_convoy.id do
      updates = [update | Enum.take(socket.assigns.convoy_updates, 19)]
      stats = Groups.calculate_convoy_stats(socket.assigns.active_convoy.id)

      {:noreply,
       socket
       |> assign(:convoy_updates, updates)
       |> assign(:convoy_stats, stats)
       |> assign(:sharing_count, stats.sharing_count)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_info(:refresh_convoy, socket) do
    if socket.assigns.active_convoy do
      new_stats = Groups.calculate_convoy_stats(socket.assigns.active_convoy.id)
      Process.send_after(self(), :refresh_convoy, 10000)
      {:noreply, assign(socket, :convoy_stats, new_stats)}
    else
      {:noreply, socket}
    end
  end

  # ==================== SCREEN NAVIGATION ====================

  @impl true
  def handle_event("open_group", %{"id" => group_id}, socket) do
    group = Groups.get_group(String.to_integer(group_id), socket.assigns.current_user.id)

    messages = Groups.get_channel_messages(get_channel_id(group.id, "general"))
    safety_messages = Groups.get_channel_messages(get_channel_id(group.id, "safety"))
    photos = Groups.get_group_photos(group.id)
    events = Groups.list_group_events(group.id)
    active_convoy = Groups.get_active_convoy(group.id)
    pinned = Groups.get_pinned_message(group.id)

    convoy_stats =
      if active_convoy, do: Groups.calculate_convoy_stats(active_convoy.id), else: nil

    convoy_updates = if active_convoy, do: Groups.get_convoy_updates(active_convoy.id), else: []

    socket =
      socket
      |> assign(:screen, :detail)
      |> assign(:selected_group, group)
      |> assign(:group_messages, messages)
      |> assign(:safety_messages, safety_messages)
      |> assign(:group_photos, photos)
      |> assign(:photos_count, length(photos))
      |> assign(:group_events, events)
      |> assign(:active_convoy, active_convoy)
      |> assign(:convoy_stats, convoy_stats)
      |> assign(:convoy_updates, convoy_updates)
      |> assign(:pinned_message, pinned)
      |> assign(:active_channel, "chat")
      |> assign(:sharing_count, if(convoy_stats, do: convoy_stats.sharing_count, else: 0))
      |> assign(:convoy_distance, if(convoy_stats, do: convoy_stats.distance, else: "?"))
      |> assign(:convoy_eta, if(convoy_stats, do: convoy_stats.eta, else: "?"))

    if active_convoy do
      Process.send_after(self(), :refresh_convoy, 5000)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    pulse_data = Groups.get_pulse_data(socket.assigns.current_user.id)
    user_groups = Groups.list_user_groups(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:screen, :list)
     |> assign(:pulse_data, pulse_data)
     |> assign(:user_groups, user_groups)
     |> assign(:display_groups, user_groups)
     |> assign(:selected_group, nil)}
  end

  # ==================== GROUP CREATION ====================

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("create_group", %{"group" => group_params}, socket) do
    case Groups.create_group(group_params, socket.assigns.current_user.id) do
      {:ok, group} ->
        user_groups = Groups.list_user_groups(socket.assigns.current_user.id)
        pulse_data = Groups.get_pulse_data(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:user_groups, user_groups)
         |> assign(:display_groups, user_groups)
         |> assign(:pulse_data, pulse_data)
         |> assign(:show_create_modal, false)
         |> put_flash(:info, "Group \"#{group.name}\" created successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :new_group_changeset, changeset)}
    end
  end

  # ==================== GROUP ACTIONS ====================

  @impl true
  def handle_event("join_group", %{"id" => group_id}, socket) do
    case Groups.add_member(String.to_integer(group_id), socket.assigns.current_user.id) do
      {:ok, _} ->
        user_groups = Groups.list_user_groups(socket.assigns.current_user.id)
        {:noreply, assign(socket, :user_groups, user_groups)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not join group")}
    end
  end

  @impl true
  def handle_event("leave_group", %{"id" => group_id}, socket) do
    case Groups.remove_member(String.to_integer(group_id), socket.assigns.current_user.id) do
      {:ok, _} ->
        user_groups = Groups.list_user_groups(socket.assigns.current_user.id)
        {:noreply, assign(socket, :user_groups, user_groups)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not leave group")}
    end
  end

  # ==================== CHANNEL NAVIGATION ====================

  @impl true
  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    group = socket.assigns.selected_group

    {messages, safety_msgs, photos, events, convoy, stats, updates} =
      case channel do
        "chat" ->
          {Groups.get_channel_messages(get_channel_id(group.id, "general")),
           socket.assigns.safety_messages, socket.assigns.group_photos,
           socket.assigns.group_events, socket.assigns.active_convoy, socket.assigns.convoy_stats,
           socket.assigns.convoy_updates}

        "safety" ->
          {socket.assigns.group_messages,
           Groups.get_channel_messages(get_channel_id(group.id, "safety")),
           socket.assigns.group_photos, socket.assigns.group_events, socket.assigns.active_convoy,
           socket.assigns.convoy_stats, socket.assigns.convoy_updates}

        "photos" ->
          {socket.assigns.group_messages, socket.assigns.safety_messages,
           Groups.get_group_photos(group.id), socket.assigns.group_events,
           socket.assigns.active_convoy, socket.assigns.convoy_stats,
           socket.assigns.convoy_updates}

        "events" ->
          {socket.assigns.group_messages, socket.assigns.safety_messages,
           socket.assigns.group_photos, Groups.list_group_events(group.id),
           socket.assigns.active_convoy, socket.assigns.convoy_stats,
           socket.assigns.convoy_updates}

        "convoy" ->
          convoy = Groups.get_active_convoy(group.id)
          stats = if convoy, do: Groups.calculate_convoy_stats(convoy.id), else: nil
          updates = if convoy, do: Groups.get_convoy_updates(convoy.id), else: []

          {socket.assigns.group_messages, socket.assigns.safety_messages,
           socket.assigns.group_photos, socket.assigns.group_events, convoy, stats, updates}
      end

    {:noreply,
     socket
     |> assign(:active_channel, channel)
     |> assign(:group_messages, messages)
     |> assign(:safety_messages, safety_msgs)
     |> assign(:group_photos, photos)
     |> assign(:photos_count, length(photos))
     |> assign(:group_events, events)
     |> assign(:active_convoy, convoy)
     |> assign(:convoy_stats, stats)
     |> assign(:convoy_updates, updates)
     |> assign(:sharing_count, if(stats, do: stats.sharing_count, else: 0))
     |> assign(:convoy_distance, if(stats, do: stats.distance, else: "?"))
     |> assign(:convoy_eta, if(stats, do: stats.eta, else: "?"))}
  end

  # ==================== MESSAGES ====================

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) when content != "" do
    group = socket.assigns.selected_group

    channel_name =
      if socket.assigns.active_channel == "chat",
        do: "general",
        else: socket.assigns.active_channel

    channel_id = get_channel_id(group.id, channel_name)

    case Groups.create_channel_message(
           %{content: content},
           socket.assigns.current_user.id,
           group.id,
           channel_id
         ) do
      {:ok, _message} ->
        messages = Groups.get_channel_messages(channel_id)

        socket =
          if socket.assigns.active_channel == "chat" do
            assign(socket, :group_messages, messages)
          else
            assign(socket, :safety_messages, messages)
          end

        {:noreply, assign(socket, :input_text, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send message")}
    end
  end

  @impl true
  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_text, message)}
  end

  # ==================== EVENTS ====================

  @impl true
  def handle_event("rsvp_event", %{"event_id" => event_id, "status" => status}, socket) do
    case Groups.rsvp_event(String.to_integer(event_id), socket.assigns.current_user.id, status) do
      {:ok, _} ->
        events = Groups.list_group_events(socket.assigns.selected_group.id)
        {:noreply, assign(socket, :group_events, events)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update RSVP")}
    end
  end

  # ==================== CONVOY ====================

  @impl true
  def handle_event("join_convoy", %{"convoy_id" => convoy_id}, socket) do
    case Groups.join_convoy(String.to_integer(convoy_id), socket.assigns.current_user.id) do
      {:ok, _} ->
        active_convoy = Groups.get_active_convoy(socket.assigns.selected_group.id)
        stats = Groups.calculate_convoy_stats(active_convoy.id)

        {:noreply,
         assign(socket, :active_convoy, active_convoy)
         |> assign(:convoy_stats, stats)
         |> assign(:is_sharing_location, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not join convoy")}
    end
  end

  @impl true
  def handle_event("share_location", %{"lat" => lat, "lng" => lng}, socket) do
    convoy = socket.assigns.active_convoy

    if convoy do
      case Groups.share_location(
             convoy.id,
             socket.assigns.current_user.id,
             String.to_float(lat),
             String.to_float(lng)
           ) do
        {:ok, _} ->
          stats = Groups.calculate_convoy_stats(convoy.id)
          updates = Groups.get_convoy_updates(convoy.id)

          {:noreply,
           socket
           |> assign(:convoy_stats, stats)
           |> assign(:convoy_updates, updates)
           |> assign(:is_sharing_location, true)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not share location")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_convoy", %{"destination" => destination}, socket) do
    group = socket.assigns.selected_group

    attrs = %{
      group_id: group.id,
      name: "#{group.name} Convoy",
      destination: destination,
      created_by_id: socket.assigns.current_user.id,
      is_active: true
    }

    case Groups.create_convoy(attrs) do
      {:ok, convoy} ->
        Groups.join_convoy(convoy.id, socket.assigns.current_user.id)
        stats = Groups.calculate_convoy_stats(convoy.id)

        {:noreply,
         socket
         |> assign(:active_convoy, convoy)
         |> assign(:convoy_stats, stats)
         |> assign(:active_channel, "convoy")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not start convoy")}
    end
  end

  # ==================== SOS ALERT ====================

  @impl true
  def handle_event("sos_alert", %{"location" => location}, socket) do
    group = socket.assigns.selected_group
    user = socket.assigns.current_user

    case Groups.send_sos_alert(group.id, user.id, location) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "SOS alert sent to all group members!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send SOS alert")}
    end
  end

  # ==================== FILTERING ====================

  @impl true
  def handle_event("search_groups", %{"value" => search_term}, socket) do
    current_user = socket.assigns.current_user

    filtered =
      socket.assigns.display_groups
      |> Enum.filter(fn group ->
        search_term == "" or
          String.contains?(String.downcase(group.name), String.downcase(search_term)) or
          (group.location &&
             String.contains?(String.downcase(group.location), String.downcase(search_term)))
      end)

    {:noreply, assign(socket, :display_groups, filtered)}
  end

  @impl true
  def handle_event("filter_groups", %{"filter" => filter}, socket) do
    current_user = socket.assigns.current_user

    display_groups =
      case filter do
        "joined" -> socket.assigns.user_groups
        "all" -> Groups.list_groups(%{for_user_id: current_user.id})
        "trips" -> Groups.list_groups(%{type: "trip", for_user_id: current_user.id})
        "guides" -> Groups.list_groups(%{type: "guide_network", for_user_id: current_user.id})
        "communities" -> Groups.list_groups(%{type: "community", for_user_id: current_user.id})
        "nearby" -> Groups.find_nearby_groups(current_user.id, 10)
        _ -> socket.assigns.user_groups
      end

    {:noreply,
     assign(socket, :filter, filter)
     |> assign(:display_groups, display_groups)}
  end

  # ==================== PRIVATE HELPERS ====================

  defp get_channel_id(group_id, channel_name) do
    case Mtaani.Repo.get_by(Mtaani.Groups.GroupChannel, group_id: group_id, name: channel_name) do
      nil -> nil
      channel -> channel.id
    end
  end

  defp get_channel_name_from_id(channel_id) do
    case Mtaani.Repo.get(Mtaani.Groups.GroupChannel, channel_id) do
      nil -> nil
      channel -> channel.name
    end
  end

  defp update_group_preview(groups, message) do
    Enum.map(groups, fn group ->
      if group.id == message.group_id do
        Map.put(group, :last_message_preview, String.slice(message.content, 0..50))
      else
        group
      end
    end)
  end

  # ==================== CSS CLASS HELPERS ====================

  defp filter_button_class(filter, current_filter) do
    if filter == current_filter do
      "px-3.5 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all bg-green-500 text-white"
    else
      "px-3.5 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all bg-[var(--color-background-secondary)] text-[var(--color-text-secondary)] border border-[var(--color-border-secondary)]"
    end
  end

  defp _channel_tab_class(channel, active_channel) do
    if channel == active_channel do
      "text-green-500 border-green-500"
    else
      "text-[var(--color-text-secondary)] border-transparent"
    end
  end

  defp _message_bubble_class(is_current_user, message_user_id) do
    if message_user_id == is_current_user do
      "bg-green-500 text-white rounded-br-md"
    else
      "bg-[var(--color-background-primary)] border border-[var(--color-border-tertiary)] text-[var(--color-text-primary)] rounded-bl-md"
    end
  end

  defp _group_type_selected_class(type, selected_type) do
    if type == selected_type do
      "border-green-500 bg-green-50"
    else
      "border-[var(--color-border-secondary)] bg-[var(--color-background-secondary)]"
    end
  end

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    try do
      Calendar.strftime(datetime, "%H:%M")
    rescue
      _ -> ""
    end
  end

  defp format_relative_time(nil), do: ""

  defp format_relative_time(datetime) do
    try do
      now = DateTime.utc_now()
      diff = DateTime.diff(now, datetime, :minute)

      cond do
        diff < 1 -> "Just now"
        diff < 60 -> "#{diff}m ago"
        diff < 1440 -> "#{div(diff, 60)}h ago"
        true -> "#{div(diff, 1440)}d ago"
      end
    rescue
      _ -> ""
    end
  end

  # ==================== NAVIGATE HANDLER ====================

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end
end
