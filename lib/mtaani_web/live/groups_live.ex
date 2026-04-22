defmodule MtaaniWeb.GroupsLive do
  use MtaaniWeb, :live_view
  import MtaaniWeb.BottomNav

  alias Mtaani.Repo
  alias Mtaani.Groups
  alias Mtaani.Groups.{Group, GroupMember, GroupMessage, GroupEvent, GroupConvoy}
  alias Mtaani.Accounts

  # ==================== MOUNT ====================

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      pulse_data = Groups.get_pulse_data(current_user.id)
      user_groups = Groups.list_user_groups(current_user.id)

      suggested_groups =
        Groups.list_groups(%{joined_by_user_id: nil, for_user_id: current_user.id})

      socket =
        socket
        |> assign(:page_title, "Groups")
        |> assign(:current_user, current_user)
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
        |> assign(:new_group, %Group{})
        |> assign(:show_emergency, false)
        |> assign(:show_status_modal, false)
        |> assign(:statuses, [])
        |> assign(:input_text, "")

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "groups_updates")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "new_message")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "new_status")
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
  end

  # ==================== REAL-TIME HANDLERS ====================

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.selected_group && message.group_id == socket.assigns.selected_group.id do
      channel_name = get_channel_name_from_id(message.channel_id)

      cond do
        socket.assigns.active_channel == "chat" and channel_name == "general" ->
          messages = [message | socket.assigns.group_messages]
          {:noreply, assign(socket, :group_messages, messages)}

        socket.assigns.active_channel == "safety" and channel_name == "safety" ->
          messages = [message | socket.assigns.safety_messages]
          {:noreply, assign(socket, :safety_messages, messages)}

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
  def handle_info({:new_status, status}, socket) do
    statuses = [status | Enum.take(socket.assigns.statuses, 19)]
    {:noreply, assign(socket, :statuses, statuses)}
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
      {:ok, message} ->
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

  @impl true
  def handle_event("send_safety_message", %{"message" => content}, socket) when content != "" do
    group = socket.assigns.selected_group
    channel_id = get_channel_id(group.id, "safety")

    case Groups.create_channel_message(
           %{content: content},
           socket.assigns.current_user.id,
           group.id,
           channel_id
         ) do
      {:ok, message} ->
        messages = Groups.get_channel_messages(channel_id)
        {:noreply, assign(socket, :safety_messages, messages)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send safety message")}
    end
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

  # ==================== PHOTOS ====================

  @impl true
  def handle_event("upload_photo", _params, socket) do
    {:noreply, push_event(socket, "upload_photo", %{})}
  end

  # ==================== EMERGENCY HANDLERS ====================

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
  def handle_event("share_location_emergency", _, socket) do
    {:noreply, push_event(socket, "share_location", %{})}
  end

  @impl true
  def handle_event("trigger_emergency", _, socket) do
    {:noreply, push_event(socket, "trigger_emergency", %{})}
  end

  # ==================== STATUS HANDLERS ====================

  @impl true
  def handle_event("show_status_modal", _, socket) do
    {:noreply, assign(socket, :show_status_modal, true)}
  end

  @impl true
  def handle_event("close_status_modal", _, socket) do
    {:noreply, assign(socket, :show_status_modal, false)}
  end

  # ==================== NAVIGATION HANDLERS ====================

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, push_navigate(socket, to: "/logout")}
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

  # ==================== PRIVATE HELPERS ====================

  defp get_channel_id(group_id, channel_name) do
    case Repo.get_by(Mtaani.Groups.GroupChannel, group_id: group_id, name: channel_name) do
      nil -> nil
      channel -> channel.id
    end
  end

  defp get_channel_name_from_id(channel_id) do
    case Repo.get(Mtaani.Groups.GroupChannel, channel_id) do
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
      "bg-green-500 text-white"
    else
      "bg-[var(--color-background-secondary)] text-[var(--color-text-secondary)] border border-[var(--color-border-secondary)]"
    end
  end

  defp channel_tab_class(channel, active_channel) do
    if channel == active_channel do
      "text-green-500 border-green-500"
    else
      "text-[var(--color-text-secondary)] border-transparent"
    end
  end

  defp message_bubble_class(is_current_user, message_user_id) do
    if message_user_id == is_current_user do
      "bg-green-500 text-white rounded-br-md"
    else
      "bg-[var(--color-background-primary)] border border-[var(--color-border-tertiary)] text-[var(--color-text-primary)] rounded-bl-md"
    end
  end

  defp group_type_selected_class(type, selected_type) do
    if type == selected_type do
      "border-green-500 bg-green-50"
    else
      "border-[var(--color-border-secondary)] bg-[var(--color-background-secondary)]"
    end
  end

  # ==================== RENDER ====================

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={MtaaniWeb.EmergencyModalLive}
      id="emergency_modal"
      show={@show_emergency}
    />
    <div class="min-h-screen bg-[var(--color-background-tertiary)]">
      <%= if @screen == :list do %>
        {render_groups_list(assigns)}
      <% else %>
        {render_group_detail(assigns)}
      <% end %>
       {render_create_modal(assigns)} {render_status_modal(assigns)}
    </div>
    """
  end

  defp render_groups_list(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-[var(--color-background-primary)] min-h-screen">
      <div class="sticky top-0 z-10 bg-[var(--color-background-primary)]/80 backdrop-blur-sm border-b border-[var(--color-border-tertiary)]">
        <div class="flex items-center justify-between px-4 py-3">
          <h1 class="text-xl font-semibold text-[var(--color-text-primary)]">Groups</h1>
          
          <div class="flex gap-2">
            <button class="w-8 h-8 rounded-full bg-[var(--color-background-secondary)] flex items-center justify-center">
              <Heroicons.magnifying_glass class="w-4 h-4 text-[var(--color-text-secondary)]" />
            </button>
            
            <button
              phx-click="open_create_modal"
              class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center"
            >
              <Heroicons.plus class="w-4 h-4 text-white" />
            </button>
          </div>
        </div>
      </div>
      
      <%= if @pulse_data.total_online > 0 or @pulse_data.recent_activity_count > 0 do %>
        <div class="mx-4 mt-4 rounded-xl overflow-hidden cursor-pointer relative h-32">
          <div class="absolute inset-0 bg-gradient-to-br from-green-900 to-green-700"></div>
          
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_20%_50%,rgba(16,185,129,.25)_0%,transparent_60%),radial-gradient(circle_at_80%_20%,rgba(59,130,246,.15)_0%,transparent_50%)]">
          </div>
          
          <div class="relative p-4 flex flex-col justify-between h-full">
            <div class="flex justify-between items-start">
              <div class="flex items-center gap-1.5 bg-white/10 rounded-full px-2.5 py-1">
                <div class="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse"></div>
                
                <span class="text-[10px] text-white/85 font-medium">
                  {@pulse_data.total_online} online now
                </span>
              </div>
              
              <%= if @pulse_data.has_active_convoy do %>
                <div class="text-xs text-white/70 bg-white/10 rounded-full px-2.5 py-1">
                  🚗 Convoy active →
                </div>
              <% end %>
            </div>
            
            <div>
              <p class="text-[10px] text-white/50 font-medium uppercase tracking-wide">
                HAPPENING IN YOUR GROUPS
              </p>
              
              <p class="text-sm text-white font-medium">
                <%= if @pulse_data.latest_moment do %>
                  {@pulse_data.latest_moment.user.name}: {String.slice(
                    @pulse_data.latest_moment.content,
                    0..50
                  )}
                <% else %>
                  <%= if @user_groups == [] do %>
                    Join or create a group to see activity
                  <% else %>
                    No recent activity
                  <% end %>
                <% end %>
              </p>
            </div>
            
            <div class="flex items-center gap-2">
              <div class="flex -space-x-1">
                <%= for member <- Enum.take(@pulse_data.recent_active_members || [], 3) do %>
                  <div class="w-5 h-5 rounded-full bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center text-[8px] text-white font-medium border-2 border-green-900">
                    {String.slice(member.user.name, 0..1)}
                  </div>
                <% end %>
                
                <%= if length(@pulse_data.recent_active_members || []) > 3 do %>
                  <div class="w-5 h-5 rounded-full bg-gray-500 flex items-center justify-center text-[8px] text-white font-medium border-2 border-green-900">
                    +{length(@pulse_data.recent_active_members) - 3}
                  </div>
                <% end %>
              </div>
              
              <span class="text-[11px] text-white/60">
                <strong class="text-green-400">{@pulse_data.recent_activity_count}</strong>
                new posts across your groups today
              </span>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mx-4 mt-4 rounded-xl overflow-hidden relative h-32">
          <div class="absolute inset-0 bg-gradient-to-br from-green-900 to-green-700 opacity-50">
          </div>
          
          <div class="relative p-4 flex flex-col justify-between h-full">
            <div class="flex justify-between items-start">
              <div class="flex items-center gap-1.5 bg-white/10 rounded-full px-2.5 py-1">
                <div class="w-1.5 h-1.5 rounded-full bg-gray-400"></div>
                 <span class="text-[10px] text-white/85 font-medium">0 online now</span>
              </div>
            </div>
            
            <div>
              <p class="text-[10px] text-white/50 font-medium uppercase tracking-wide">
                HAPPENING IN YOUR GROUPS
              </p>
              
              <p class="text-sm text-white/70 font-medium">
                No activity yet. Join a group to get started!
              </p>
            </div>
            
            <div class="flex items-center gap-2">
              <span class="text-[11px] text-white/60">Be the first to post in your groups</span>
            </div>
          </div>
        </div>
      <% end %>
      
      <div class="flex gap-1.5 px-4 py-3 overflow-x-auto scrollbar-hide">
        <%= for {filter, label} <- [{"all", "All"}, {"joined", "Joined"}, {"trips", "Trips"}, {"guides", "Guides"}, {"communities", "Communities"}, {"nearby", "Nearby"}] do %>
          <button
            phx-click="filter_groups"
            phx-value-filter={filter}
            class={filter_button_class(filter, @filter)}
          >
            {label}
          </button>
        <% end %>
      </div>
      
      <div class="px-4 pb-20 space-y-3">
        <%= for group <- Enum.take(@display_groups, 2) do %>
          <div
            phx-click="open_group"
            phx-value-id={group.id}
            class="rounded-xl overflow-hidden border border-[var(--color-border-tertiary)] bg-[var(--color-background-primary)] cursor-pointer"
          >
            <div class="h-28 relative overflow-hidden">
              <div class="absolute inset-0 flex items-center justify-center text-5xl bg-gradient-to-br from-green-100 to-green-200">
                {if group.type == "trip", do: "🚗", else: "👥"}
              </div>
              
              <div class="absolute inset-0 bg-gradient-to-t from-black/55 via-black/10 to-transparent">
              </div>
              
              <div class="absolute top-2 left-2 flex gap-1">
                <span class="text-[9px] font-medium px-2 py-0.5 rounded-full bg-green-100 text-green-800">
                  {if group.type == "trip", do: "Trip group", else: String.capitalize(group.type)}
                </span>
              </div>
              
              <div class="absolute top-2 right-2 flex gap-1">
                <div class="flex -space-x-1">
                  <%= for member <- Enum.take(group.recent_members || [], 2) do %>
                    <div class="w-5 h-5 rounded-full bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center text-[7px] text-white font-medium border-2 border-black/30">
                      {String.slice(member.user.name, 0..1)}
                    </div>
                  <% end %>
                </div>
                
                <%= if group.unread_count > 0 do %>
                  <div class="min-w-[20px] h-5 rounded-full bg-green-500 flex items-center justify-center px-1.5 text-[10px] font-medium text-white">
                    {if group.unread_count > 9, do: "9+", else: group.unread_count}
                  </div>
                <% end %>
              </div>
              
              <div class="absolute bottom-2 left-3 text-white font-medium text-sm">{group.name}</div>
            </div>
            
            <div class="p-3">
              <div class="flex items-center gap-1 text-xs text-[var(--color-text-secondary)]">
                <span class="font-medium text-[var(--color-text-primary)]">
                  {group.last_message_sender || "Group"}
                </span>
                 <span class="truncate">{group.last_message_preview || "No messages yet"}</span>
              </div>
              
              <div class="flex justify-between items-center mt-2">
                <div class="flex gap-2">
                  <%= if group.location do %>
                    <span class="text-[10px] font-medium px-2 py-0.5 rounded-lg bg-green-50 text-green-700">
                      📍 {group.location}
                    </span>
                  <% end %>
                  
                  <%= if group.type == "guide_network" do %>
                    <span class="text-[10px] font-medium px-2 py-0.5 rounded-lg bg-blue-50 text-blue-700">
                      ✅ Verified
                    </span>
                  <% end %>
                </div>
                
                <%= if group.activity_level != :none do %>
                  <div class="flex items-center gap-1">
                    <div class={[
                      "w-1.5 h-1.5 rounded-full",
                      if(group.activity_level == :high,
                        do: "bg-green-500",
                        else:
                          if(group.activity_level == :medium, do: "bg-amber-500", else: "bg-gray-400")
                      )
                    ]}>
                    </div>
                    
                    <span class="text-[10px] font-medium text-amber-700">{group.activity_label}</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if length(@display_groups) > 2 do %>
          <div class="text-[11px] font-medium text-[var(--color-text-secondary)] tracking-wide pt-2">
            MORE GROUPS
          </div>
        <% end %>
        
        <%= for group <- Enum.drop(@display_groups, 2) do %>
          <div
            phx-click="open_group"
            phx-value-id={group.id}
            class="flex items-center gap-3 p-3 bg-[var(--color-background-primary)] rounded-xl border border-[var(--color-border-tertiary)] cursor-pointer"
          >
            <div class="w-11 h-11 rounded-xl bg-purple-100 flex items-center justify-center text-xl">
              {if group.type == "trip", do: "🚗", else: "👥"}
            </div>
            
            <div class="flex-1 min-w-0">
              <div class="flex justify-between items-center">
                <h3 class="font-medium text-sm text-[var(--color-text-primary)]">{group.name}</h3>
                
                <span class="text-[11px] text-[var(--color-text-secondary)]">
                  {group.last_activity_time}
                </span>
              </div>
              
              <p class="text-xs text-[var(--color-text-secondary)] truncate">
                {group.last_message_preview || group.description || "Join the conversation"}
              </p>
              
              <div class="flex gap-1 mt-1">
                <span class="text-[9px] font-medium px-1.5 py-0.5 rounded-md bg-green-50 text-green-700">
                  ✅ {group.trust_score}%
                </span>
              </div>
            </div>
            
            <div class="flex flex-col items-end gap-1">
              <%= if group.unread_count > 0 do %>
                <div class="w-5 h-5 rounded-full bg-green-500 flex items-center justify-center text-[10px] font-medium text-white">
                  {group.unread_count}
                </div>
              <% end %>
              
              <%= if group.is_active do %>
                <div class="w-2 h-2 rounded-full bg-green-400"></div>
              <% end %>
            </div>
          </div>
        <% end %>
        
        <%= if @display_groups == [] do %>
          <div class="text-center py-12">
            <div class="text-5xl mb-3">👥</div>
            
            <h3 class="text-base font-medium text-[var(--color-text-primary)]">No groups yet</h3>
            
            <p class="text-xs text-[var(--color-text-secondary)] mt-1">
              Create a group or join existing ones
            </p>
            
            <button
              phx-click="open_create_modal"
              class="mt-4 px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium"
            >
              Create group
            </button>
          </div>
        <% end %>
      </div>
      
      <button
        phx-click="open_create_modal"
        class="fixed bottom-20 right-4 w-12 h-12 rounded-full bg-green-500 shadow-lg flex items-center justify-center text-white text-xl z-10"
      >
        <Heroicons.plus class="w-6 h-6" />
      </button>
       <.bottom_nav current="groups" />
    </div>
    """
  end

  defp render_group_detail(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-[var(--color-background-tertiary)] min-h-screen">
      <div class="relative h-40 overflow-hidden">
        <div class="absolute inset-0 flex items-center justify-center text-6xl bg-gradient-to-br from-green-700 to-green-800">
          {if @selected_group.type == "trip", do: "🚗", else: "👥"}
        </div>
        
        <div class="absolute inset-0 bg-gradient-to-t from-black/65 via-black/25 to-transparent">
        </div>
        
        <button
          phx-click="go_back"
          class="absolute top-3 left-3 w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white"
        >
          <Heroicons.arrow_left class="w-4 h-4" />
        </button>
        
        <div class="absolute top-3 right-3 flex gap-1.5">
          <button class="w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white">
            <Heroicons.magnifying_glass class="w-4 h-4" />
          </button>
          
          <button class="w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white">
            <Heroicons.ellipsis_horizontal class="w-4 h-4" />
          </button>
        </div>
        
        <div class="absolute bottom-0 left-0 right-0 p-4">
          <h2 class="text-xl font-semibold text-white">{@selected_group.name}</h2>
          
          <div class="flex items-center gap-2 mt-1">
            <div class="flex items-center gap-1">
              <div class="w-1.5 h-1.5 rounded-full bg-green-400"></div>
               <span class="text-[11px] text-white/70">{@selected_group.online_count} online</span>
            </div>
             <span class="text-[11px] text-white/70">{@selected_group.member_count} members</span>
            <span class="text-[10px] font-medium px-1.5 py-0.5 rounded-md bg-green-500/20 text-green-400 border border-green-500/30">
              Trust {@selected_group.trust_score}%
            </span>
          </div>
        </div>
      </div>
      
      <div class="flex items-center gap-2 px-4 py-2.5 bg-[var(--color-background-primary)] border-b border-[var(--color-border-tertiary)] overflow-x-auto scrollbar-hide">
        <button class="w-9 h-9 rounded-full border border-dashed border-[var(--color-border-secondary)] flex items-center justify-center text-[var(--color-text-secondary)]">
          <Heroicons.plus class="w-4 h-4" />
        </button>
        
        <%= for member <- Enum.take(@selected_group.members || [], 10) do %>
          <div class="flex flex-col items-center gap-0.5 flex-shrink-0">
            <div class="relative w-9 h-9 rounded-full bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center text-white text-[10px] font-medium border-2 border-[var(--color-background-primary)]">
              {String.slice(member.user.name, 0..1)}
              <%= if member.is_online do %>
                <div class="absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full bg-green-500 border border-[var(--color-background-primary)]">
                </div>
              <% end %>
            </div>
            
            <span class="text-[9px] text-[var(--color-text-secondary)]">
              {String.slice(member.user.name, 0..8)}
            </span>
          </div>
        <% end %>
      </div>
      
      <div class="flex overflow-x-auto scrollbar-hide bg-[var(--color-background-primary)] border-b border-[var(--color-border-tertiary)]">
        <%= for {channel, label, icon} <- [{"chat", "general", "#"}, {"safety", "safety", "#"}, {"photos", "photos", "#"}, {"events", "events", "🗓"}, {"convoy", "convoy", "🚗"}] do %>
          <button
            phx-click="switch_channel"
            phx-value-channel={channel}
            class={[
              channel_tab_class(channel, @active_channel),
              "px-3.5 py-2.5 text-xs font-medium whitespace-nowrap flex items-center gap-1 border-b-2 transition-colors"
            ]}
          >
            {icon} {label}
          </button>
        <% end %>
      </div>
      
      <%= if @active_channel == "chat" do %>
        <div class="flex flex-col h-[calc(100vh-280px)]">
          <%= if @pinned_message do %>
            <div class="bg-amber-50 border-b border-amber-200 px-4 py-2 flex items-center gap-2 cursor-pointer">
              <Heroicons.bookmark class="w-3.5 h-3.5 text-amber-600" />
              <span class="text-[11px] text-amber-800 flex-1 truncate">
                {@pinned_message.user.name}: {String.slice(@pinned_message.content, 0..60)}
              </span>
               <span class="text-[10px] text-amber-600 font-medium">View</span>
            </div>
          <% end %>
          
          <div class="flex-1 overflow-y-auto p-4 space-y-3" id="messages-container">
            <%= if @group_messages == [] do %>
              <div class="text-center py-8">
                <div class="text-4xl mb-2">💬</div>
                
                <p class="text-sm text-[var(--color-text-secondary)]">No messages yet</p>
                
                <p class="text-xs text-[var(--color-text-secondary)] mt-1">
                  Be the first to send a message!
                </p>
              </div>
            <% end %>
            
            <%= for message <- @group_messages do %>
              <div class={[
                "flex gap-2",
                if(message.user_id == @current_user.id, do: "flex-row-reverse", else: "")
              ]}>
                <div class="w-7 h-7 rounded-full bg-gradient-to-br from-red-500 to-red-600 flex items-center justify-center text-[9px] text-white font-medium flex-shrink-0">
                  {String.slice(message.user.name, 0..2)}
                </div>
                
                <div class={[
                  "max-w-[78%]",
                  if(message.user_id == @current_user.id, do: "items-end", else: "")
                ]}>
                  <div class={[
                    "flex gap-2 text-[10px] font-medium text-[var(--color-text-secondary)] mb-0.5 px-1",
                    if(message.user_id == @current_user.id, do: "justify-end", else: "")
                  ]}>
                    <span>{message.user.name}</span>
                    <%= if message.user.is_guide do %>
                      <span class="text-blue-500">· Guide</span>
                    <% end %>
                  </div>
                  
                  <div class={[
                    "px-3 py-2 rounded-2xl text-[13px] leading-relaxed break-words",
                    message_bubble_class(@current_user.id, message.user_id)
                  ]}>
                    {message.content}
                  </div>
                  
                  <div class={[
                    "flex gap-2 text-[9px] text-[var(--color-text-secondary)] mt-0.5 px-1",
                    if(message.user_id == @current_user.id, do: "justify-end", else: "")
                  ]}>
                    <span>{format_time(message.inserted_at)}</span>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if @typing_users != [] do %>
              <div class="flex items-center gap-1 pl-9">
                <div class="w-1 h-1 rounded-full bg-[var(--color-text-secondary)] animate-bounce">
                </div>
                
                <div
                  class="w-1 h-1 rounded-full bg-[var(--color-text-secondary)] animate-bounce"
                  style="animation-delay: 0.2s"
                >
                </div>
                
                <div
                  class="w-1 h-1 rounded-full bg-[var(--color-text-secondary)] animate-bounce"
                  style="animation-delay: 0.4s"
                >
                </div>
                
                <span class="text-[11px] text-[var(--color-text-secondary)] ml-1">
                  {Enum.join(@typing_users, ", ")} is typing...
                </span>
              </div>
            <% end %>
          </div>
          
          <div class="p-3 bg-[var(--color-background-primary)] border-t border-[var(--color-border-tertiary)] flex items-center gap-1.5">
            <button class="w-8 h-8 rounded-full text-[var(--color-text-secondary)]">
              <Heroicons.paper_clip class="w-4 h-4 mx-auto" />
            </button>
            
            <button class="w-8 h-8 rounded-full text-[var(--color-text-secondary)]">
              <Heroicons.camera class="w-4 h-4 mx-auto" />
            </button>
            
            <button class="w-8 h-8 rounded-full text-[var(--color-text-secondary)]">
              <Heroicons.map_pin class="w-4 h-4 mx-auto" />
            </button>
            
            <div class="flex-1 bg-[var(--color-background-secondary)] rounded-full px-3 py-2">
              <input
                type="text"
                placeholder="Message #general…"
                class="w-full bg-transparent border-none outline-none text-sm text-[var(--color-text-primary)] placeholder:text-[var(--color-text-secondary)]"
                phx-keydown="send_message"
                phx-key="Enter"
                id="message_input"
              />
            </div>
            
            <button
              phx-click="send_message"
              class="w-9 h-9 rounded-full bg-green-500 flex items-center justify-center text-white"
            >
              <Heroicons.arrow_up class="w-4 h-4" />
            </button>
          </div>
        </div>
      <% end %>
      
      <%= if @active_channel == "safety" do %>
        <div class="flex flex-col h-[calc(100vh-280px)]">
          <div class="flex-1 overflow-y-auto p-4 space-y-3">
            <%= for message <- @safety_messages do %>
              <div class="flex gap-2">
                <div class="w-7 h-7 rounded-full bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center text-[9px] text-white font-medium">
                  {String.slice(message.user.name, 0..2)}
                </div>
                
                <div>
                  <div class="text-[10px] font-medium text-[var(--color-text-secondary)] mb-0.5">
                    {message.user.name} {if message.user.is_guide, do: "· Guide"}
                  </div>
                  
                  <div class="bg-amber-50 border border-amber-200 border-l-4 border-l-amber-500 rounded-lg p-3 max-w-[90%]">
                    <div class="flex items-center gap-1 text-xs font-medium text-amber-800 mb-1">
                      🛡 Safety note
                    </div>
                    
                    <div class="text-xs text-amber-800">{message.content}</div>
                  </div>
                  
                  <div class="text-[9px] text-[var(--color-text-secondary)] mt-0.5">
                    {format_time(message.inserted_at)}
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if @safety_messages == [] do %>
              <div class="text-center py-8">
                <div class="text-4xl mb-2">🛡️</div>
                
                <p class="text-sm text-[var(--color-text-secondary)]">No safety updates yet</p>
                
                <p class="text-xs text-[var(--color-text-secondary)] mt-1">
                  Share route updates, warnings, or tips
                </p>
              </div>
            <% end %>
          </div>
          
          <div class="p-3 bg-[var(--color-background-primary)] border-t border-[var(--color-border-tertiary)] flex items-center gap-1.5">
            <button class="w-8 h-8 rounded-full text-[var(--color-text-secondary)]">
              <Heroicons.map_pin class="w-4 h-4 mx-auto" />
            </button>
            
            <div class="flex-1 bg-[var(--color-background-secondary)] rounded-full px-3 py-2">
              <input
                type="text"
                placeholder="Report safety info…"
                class="w-full bg-transparent border-none outline-none text-sm text-[var(--color-text-primary)]"
                id="safety_input"
              />
            </div>
            
            <button
              phx-click="send_safety_message"
              class="w-9 h-9 rounded-full bg-green-500 flex items-center justify-center text-white"
            >
              <Heroicons.arrow_up class="w-4 h-4" />
            </button>
          </div>
        </div>
      <% end %>
      
      <%= if @active_channel == "photos" do %>
        <div class="h-[calc(100vh-280px)] overflow-y-auto p-4">
          <div class="flex justify-between items-center mb-3">
            <span class="text-sm font-medium text-[var(--color-text-primary)]">
              Group media · {@photos_count} files
            </span>
             <button phx-click="upload_photo" class="text-xs text-green-500">Add photo</button>
          </div>
          
          <%= if @group_photos != [] do %>
            <div class="grid grid-cols-3 gap-0.5 rounded-xl overflow-hidden">
              <%= for photo <- Enum.take(@group_photos, 9) do %>
                <div class="aspect-square bg-green-100 flex items-center justify-center text-3xl cursor-pointer relative group">
                  <%= if !photo.url do %>
                    <div class="text-3xl">📸</div>
                  <% end %>
                  
                  <%= if photo.index == 8 && length(@group_photos) > 9 do %>
                    <div class="absolute inset-0 bg-black/50 flex items-center justify-center text-white font-medium text-sm">
                      +{length(@group_photos) - 8}
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-12">
              <div class="text-5xl mb-3">📷</div>
              
              <p class="text-sm text-[var(--color-text-secondary)]">No photos yet</p>
              
              <p class="text-xs text-[var(--color-text-secondary)] mt-1">
                Share your travel memories with the group
              </p>
            </div>
          <% end %>
        </div>
      <% end %>
      
      <%= if @active_channel == "events" do %>
        <div class="h-[calc(100vh-280px)] overflow-y-auto p-4 space-y-3">
          <h3 class="text-sm font-medium text-[var(--color-text-primary)]">Upcoming events</h3>
          
          <%= for event <- @group_events do %>
            <div class="bg-[var(--color-background-primary)] border border-[var(--color-border-tertiary)] rounded-xl overflow-hidden">
              <div class="h-16 bg-gradient-to-r from-green-100 to-green-200 flex items-center justify-center text-2xl relative">
                🥾
                <div class="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
                
                <div class="absolute bottom-1 left-3 flex items-center gap-1.5">
                  <div class="bg-white rounded-lg px-1.5 py-0.5 text-center">
                    <div class="text-sm font-semibold text-gray-900 leading-tight">
                      {event.event_date.day}
                    </div>
                    
                    <div class="text-[8px] text-gray-500 font-medium">
                      {format_month(event.event_date)}
                    </div>
                  </div>
                   <span class="text-xs font-medium text-white">{event.title}</span>
                </div>
              </div>
              
              <div class="p-3">
                <p class="text-[11px] text-[var(--color-text-secondary)] mb-2">
                  {event.location || "Location TBD"} · {format_time(event.event_date)}
                </p>
                
                <div class="flex justify-between items-center">
                  <span class="text-[11px] text-[var(--color-text-secondary)]">
                    ✅ {event.attendees_count} going
                  </span>
                  
                  <button
                    phx-click="rsvp_event"
                    phx-value-event-id={event.id}
                    phx-value-status="going"
                    class="px-3 py-1 rounded-lg bg-green-500 text-white text-[11px] font-medium"
                  >
                    Going
                  </button>
                </div>
              </div>
            </div>
          <% end %>
          
          <%= if @group_events == [] do %>
            <div class="text-center py-8">
              <div class="text-5xl mb-3">🗓️</div>
              
              <p class="text-sm text-[var(--color-text-secondary)]">No upcoming events</p>
              
              <p class="text-xs text-[var(--color-text-secondary)] mt-1">
                Create an event to plan group activities
              </p>
            </div>
          <% end %>
        </div>
      <% end %>
      
      <%= if @active_channel == "convoy" do %>
        <div class="h-[calc(100vh-280px)] overflow-y-auto">
          <%= if @active_convoy do %>
            <div class="bg-gradient-to-r from-amber-700 to-orange-700 p-5 space-y-3">
              <div class="flex items-center gap-1.5">
                <div class="w-1.5 h-1.5 rounded-full bg-amber-300 animate-pulse"></div>
                 <span class="text-[10px] text-white/55 font-medium tracking-wide">LIVE CONVOY</span>
              </div>
              
              <h3 class="text-xl font-semibold text-white">{@active_convoy.name}</h3>
              
              <p class="text-xs text-white/65">
                {@active_convoy.destination || "Destination not set"}
              </p>
              
              <div class="flex gap-3 flex-wrap">
                <%= for participant <- @active_convoy.participants do %>
                  <div class="flex flex-col items-center gap-1">
                    <div class="relative w-10 h-10 rounded-full bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white text-xs font-medium border-2 border-white/30">
                      {String.slice(participant.user.name, 0..2)}
                      <div class={[
                        "absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-amber-700",
                        if(participant.is_sharing_location, do: "bg-green-500", else: "bg-gray-400")
                      ]}>
                      </div>
                    </div>
                    
                    <span class="text-[9px] text-white/70">
                      {String.slice(participant.user.name, 0..10)}
                    </span>
                  </div>
                <% end %>
              </div>
              
              <button
                phx-click="join_convoy"
                phx-value-convoy_id={@active_convoy.id}
                class="w-full py-3 rounded-xl text-white text-sm font-medium flex items-center justify-center gap-2 bg-white/20 border border-white/30"
              >
                <Heroicons.map_pin class="w-4 h-4" /> Share my location with convoy
              </button>
            </div>
            
            <div class="grid grid-cols-3 bg-[var(--color-background-primary)] border-b border-[var(--color-border-tertiary)]">
              <div class="text-center py-3 border-r border-[var(--color-border-tertiary)]">
                <div class="text-xl font-semibold text-[var(--color-text-primary)]">
                  {@convoy_distance}
                </div>
                
                <div class="text-[9px] text-[var(--color-text-secondary)]">To destination</div>
              </div>
              
              <div class="text-center py-3 border-r border-[var(--color-border-tertiary)]">
                <div class="text-xl font-semibold text-[var(--color-text-primary)]">
                  {@sharing_count}
                </div>
                
                <div class="text-[9px] text-[var(--color-text-secondary)]">Sharing live</div>
              </div>
              
              <div class="text-center py-3">
                <div class="text-xl font-semibold text-[var(--color-text-primary)]">
                  {@convoy_eta}
                </div>
                
                <div class="text-[9px] text-[var(--color-text-secondary)]">Est. arrival</div>
              </div>
            </div>
            
            <div class="p-4 space-y-2">
              <div class="text-[11px] font-medium text-[var(--color-text-secondary)] tracking-wide">
                LIVE UPDATES
              </div>
              
              <%= for update <- @convoy_updates do %>
                <div class="flex items-center gap-2 p-3 bg-[var(--color-background-primary)] border border-[var(--color-border-tertiary)] rounded-xl">
                  <div class="text-xl">{update.icon || "📍"}</div>
                  
                  <div class="flex-1">
                    <div class="text-xs font-medium text-[var(--color-text-primary)]">
                      {update.user.name} {update.action}
                    </div>
                    
                    <div class="text-[11px] text-[var(--color-text-secondary)]">{update.details}</div>
                  </div>
                  
                  <div class="text-[10px] text-[var(--color-text-secondary)]">
                    {format_relative_time(update.inserted_at)}
                  </div>
                </div>
              <% end %>
              
              <div class="flex items-center gap-3 p-3 bg-red-50 border border-red-200 rounded-xl">
                <div class="text-2xl">🆘</div>
                
                <div class="flex-1">
                  <div class="text-sm font-medium text-red-800">Group emergency alert</div>
                  
                  <div class="text-[11px] text-red-700">Instantly notify all convoy members</div>
                </div>
                
                <button
                  phx-click="sos_alert"
                  class="px-4 py-2 bg-red-600 text-white rounded-lg text-xs font-medium"
                >
                  SOS
                </button>
              </div>
            </div>
          <% else %>
            <div class="p-8 text-center">
              <div class="text-5xl mb-3">🚗</div>
              
              <h3 class="text-base font-medium text-[var(--color-text-primary)]">No active convoy</h3>
              
              <p class="text-xs text-[var(--color-text-secondary)] mt-1">
                Start a convoy to share live locations with group members
              </p>
              
              <button
                phx-click="start_convoy"
                class="mt-4 px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium"
              >
                Start convoy
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_create_modal(assigns) do
    ~H"""
    <%= if @show_create_modal do %>
      <div class="fixed inset-0 bg-black/50 z-50 flex items-end" phx-click="close_create_modal">
        <div
          class="bg-[var(--color-background-primary)] rounded-t-2xl w-full max-h-[85%] overflow-y-auto"
          phx-click-away="close_create_modal"
        >
          <div class="w-8 h-1 bg-[var(--color-border-secondary)] rounded-full mx-auto my-3"></div>
          
          <h3 class="text-base font-medium text-[var(--color-text-primary)] px-5 pb-3 border-b border-[var(--color-border-tertiary)]">
            Create a group ✦
          </h3>
          
          <form phx-submit="create_group" class="p-5">
            <label class="text-[11px] font-medium text-[var(--color-text-secondary)] mb-1 block">
              Group name
            </label>
            
            <input
              type="text"
              name="group[name]"
              placeholder="e.g. Mombasa Road Trip 2026"
              class="w-full bg-[var(--color-background-secondary)] border border-[var(--color-border-secondary)] rounded-xl px-3 py-2.5 text-sm text-[var(--color-text-primary)] mb-4 outline-none"
              required
            />
            <label class="text-[11px] font-medium text-[var(--color-text-secondary)] mb-1 block">
              Description
            </label>
             <textarea
              name="group[description]"
              placeholder="What's this group about?"
              rows="3"
              class="w-full bg-[var(--color-background-secondary)] border border-[var(--color-border-secondary)] rounded-xl px-3 py-2.5 text-sm text-[var(--color-text-primary)] mb-4 outline-none resize-none"
            ></textarea>
            <label class="text-[11px] font-medium text-[var(--color-text-secondary)] mb-1 block">
              Group type
            </label>
            
            <div class="grid grid-cols-2 gap-2 mb-4">
              <%= for {type, icon, label, desc} <- [{"trip", "🎒", "Trip group", "Built around a journey"}, {"community", "🏘️", "Community", "Built around a topic"}, {"guide_network", "🧭", "Guide network", "Verified guides only"}, {"private", "🔒", "Private", "Invite only"}] do %>
                <label class={[
                  group_type_selected_class(type, @new_group.type),
                  "border rounded-xl p-3 text-center cursor-pointer transition-all"
                ]}>
                  <input
                    type="radio"
                    name="group[type]"
                    value={type}
                    checked={@new_group.type == type}
                    class="hidden"
                  />
                  <div class="text-2xl mb-1">{icon}</div>
                  
                  <div class="text-xs font-medium text-[var(--color-text-primary)]">{label}</div>
                  
                  <div class="text-[10px] text-[var(--color-text-secondary)]">{desc}</div>
                </label>
              <% end %>
            </div>
            
            <label class="text-[11px] font-medium text-[var(--color-text-secondary)] mb-1 block">
              Home location
            </label>
            
            <input
              type="text"
              name="group[location]"
              placeholder="e.g. Nairobi, Kenya"
              class="w-full bg-[var(--color-background-secondary)] border border-[var(--color-border-secondary)] rounded-xl px-3 py-2.5 text-sm text-[var(--color-text-primary)] mb-4 outline-none"
            />
            <button type="submit" class="w-full py-3 bg-green-500 text-white rounded-xl font-medium">
              Create group
            </button>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_status_modal(assigns) do
    ~H"""
    <%= if @show_status_modal do %>
      <div
        class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center"
        phx-click="close_status_modal"
      >
        <div class="bg-[var(--color-background-primary)] rounded-2xl p-6 max-w-md w-full mx-4">
          <h2 class="text-xl font-semibold text-[var(--color-text-primary)] mb-4">Add Status</h2>
          
          <div class="space-y-4">
            <div class="border-2 border-dashed border-[var(--color-border-secondary)] rounded-xl p-8 text-center">
              <Heroicons.photo class="w-12 h-12 mx-auto text-[var(--color-text-secondary)]" />
              <p class="text-[var(--color-text-secondary)] mt-2">Tap to upload photo or video</p>
               <input type="file" accept="image/*,video/*" class="hidden" id="status-media" />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-[var(--color-text-primary)] mb-1">
                Caption (optional)
              </label>
               <textarea
                rows="2"
                class="w-full bg-[var(--color-background-secondary)] border border-[var(--color-border-secondary)] rounded-xl px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none"
              ></textarea>
            </div>
            
            <div class="flex gap-3">
              <button
                phx-click="close_status_modal"
                class="flex-1 px-4 py-2 border border-[var(--color-border-secondary)] rounded-lg text-[var(--color-text-primary)] hover:bg-[var(--color-background-secondary)]"
              >
                Cancel
              </button>
              
              <button class="flex-1 bg-green-500 text-white py-2 rounded-lg hover:bg-green-600">
                Share Status
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ==================== HELPER FUNCTIONS FOR TEMPLATE ====================

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    try do
      Calendar.strftime(datetime, "%H:%M")
    rescue
      _ -> ""
    end
  end

  defp format_month(nil), do: ""

  defp format_month(datetime) do
    try do
      Calendar.strftime(datetime, "%b") |> String.upcase()
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
end
