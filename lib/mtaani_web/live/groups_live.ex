defmodule MtaaniWeb.GroupsLive do
  use MtaaniWeb, :live_view
  alias Mtaani.Repo
  alias Mtaani.Chat.Group
  alias Mtaani.Chat.Message
  alias Mtaani.Accounts.User

  @impl true
def mount(_params, _session, socket) do
  import Ecto.Query
  
  current_user_id = get_current_user_id(socket)
  
  # Fix the query syntax
  query = from(g in Group, order_by: [desc: g.updated_at])
  groups = Repo.all(query)
  
  socket =
    socket
    |> assign(:active_tab, "groups")
    |> assign(:show_emergency, false)
    |> assign(:groups, groups)
    |> assign(:selected_group, nil)
    |> assign(:messages, [])
    |> assign(:input_text, "")
    |> assign(:show_form, false)
    |> assign(:current_user_id, current_user_id)
    |> assign(:show_status_modal, false)
    |> assign(:statuses, [])

  if connected?(socket) do
    Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    Phoenix.PubSub.subscribe(Mtaani.PubSub, "new_message")
    Phoenix.PubSub.subscribe(Mtaani.PubSub, "new_status")
  end

  {:ok, socket}
end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if socket.assigns.selected_group && message.group_id == socket.assigns.selected_group.id do
      messages = socket.assigns.messages ++ [message]
      {:noreply, assign(socket, :messages, messages)}
    else
      # Update group preview in sidebar
      groups = update_group_preview(socket.assigns.groups, message)
      {:noreply, assign(socket, :groups, groups)}
    end
  end

  @impl true
  def handle_info({:new_status, status}, socket) do
    statuses = [status | socket.assigns.statuses]
    {:noreply, assign(socket, :statuses, statuses)}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_event("select_group", %{"id" => group_id}, socket) do
    group = Repo.get(Group, group_id) 
           |> Repo.preload(messages: [user: [:user]], order_by: [asc: :inserted_at])
    messages = group.messages
    {:noreply, assign(socket, selected_group: group, messages: messages, show_form: false)}
  end

  @impl true
  def handle_event("new_group", _, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  @impl true
  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  @impl true
  def handle_event("create_group", %{"name" => name, "description" => description}, socket) do
    changeset = Group.changeset(%Group{}, %{
      name: name, 
      description: description, 
      created_by: socket.assigns.current_user_id
    })

    case Repo.insert(changeset) do
      {:ok, group} ->
        groups = [group | socket.assigns.groups]
        {:noreply, assign(socket, groups: groups, show_form: false)}
      {:error, _changeset} ->
        {:noreply, assign(socket, error: "Invalid group details")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    changeset = Message.changeset(%Message{}, %{
      content: message,
      user_id: socket.assigns.current_user_id,
      group_id: socket.assigns.selected_group.id
    })

    case Repo.insert(changeset) do
      {:ok, message} ->
        message = Repo.preload(message, :user)
        Phoenix.PubSub.broadcast(Mtaani.PubSub, "new_message", {:new_message, message})
        messages = socket.assigns.messages ++ [message]
        {:noreply, assign(socket, [messages: messages, input_text: ""])}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update-input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_text, message)}
  end

  @impl true
  def handle_event("show_status_modal", _, socket) do
    {:noreply, assign(socket, show_status_modal: true)}
  end

  @impl true
  def handle_event("close_status_modal", _, socket) do
    {:noreply, assign(socket, show_status_modal: false)}
  end

  # Emergency and navigation handlers
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

  # Emergency handlers
  def handle_event("open_emergency", _, socket), do: {:noreply, assign(socket, :show_emergency, true)}
  def handle_event("close_emergency", _, socket), do: {:noreply, assign(socket, :show_emergency, false)}
  def handle_event("call_police", _, socket), do: {:noreply, push_event(socket, "call_number", %{number: "999"})}
  def handle_event("call_ambulance", _, socket), do: {:noreply, push_event(socket, "call_number", %{number: "911"})}
  def handle_event("call_contact", %{"phone" => phone}, socket), do: {:noreply, push_event(socket, "call_number", %{number: phone})}
  def handle_event("share_location", _, socket), do: {:noreply, push_event(socket, "share_location", %{})}
  def handle_event("sos_alert", _, socket), do: {:noreply, push_event(socket, "sos_alert", %{})}
  def handle_event("trigger_emergency", _, socket), do: {:noreply, push_event(socket, "trigger_emergency", %{})}

  # Temporary placeholder - will be replaced with actual session user
  defp get_current_user_id(_socket) do
    # TODO: Get from session when authentication is complete
    1
  end

  defp update_group_preview(groups, message) do
    # Update the group's last message preview
    Enum.map(groups, fn group ->
      if group.id == message.group_id do
        %{group | updated_at: message.inserted_at}
      else
        group
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20 h-full flex">
      <!-- Status Bar (Snapchat-like) -->
      <div class="fixed top-16 left-0 right-0 bg-white border-b border-onyx-mauve/20 px-4 py-2 z-10 overflow-x-auto whitespace-nowrap scrollbar-hide">
        <div class="flex gap-3">
          <!-- My Status -->
          <button phx-click="show_status_modal" class="flex flex-col items-center gap-1">
            <div class="w-14 h-14 rounded-full bg-gradient-to-tr from-verdant-forest to-verdant-sage p-0.5">
              <div class="w-full h-full rounded-full bg-white flex items-center justify-center">
                <svg class="w-6 h-6 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
            </div>
            <span class="text-xs text-onyx-deep">My Status</span>
          </button>
          
          <!-- Friends' Statuses -->
          <%= for status <- @statuses do %>
            <div class="flex flex-col items-center gap-1">
              <div class="w-14 h-14 rounded-full bg-gradient-to-tr from-verdant-clay to-verdant-sage p-0.5">
                <div class="w-full h-full rounded-full bg-white flex items-center justify-center">
                  <img src={status.media_thumbnail} class="w-full h-full rounded-full object-cover" />
                </div>
              </div>
              <span class="text-xs text-onyx-deep truncate w-14 text-center"><%= status.user.name %></span>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Groups Sidebar -->
      <div class="w-80 bg-white border-r border-onyx-mauve/20 flex flex-col mt-24">
        <div class="p-4 border-b border-onyx-mauve/20">
          <div class="flex justify-between items-center">
            <h1 class="text-xl font-semibold text-onyx-deep">Chats</h1>
            <button phx-click="new_group" class="text-verdant-forest hover:text-verdant-deep">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </button>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto">
          <%= for group <- @groups do %>
            <button
              phx-click="select_group"
              phx-value-id={group.id}
              class={[
                "w-full p-4 text-left border-b border-onyx-mauve/10 hover:bg-onyx-mauve/5 transition-colors",
                @selected_group && @selected_group.id == group.id && "bg-verdant-sage/10"
              ]}
            >
              <div class="flex items-center gap-3">
                <div class="w-12 h-12 rounded-full bg-verdant-forest/10 flex items-center justify-center">
                  <span class="text-verdant-forest font-semibold"><%= String.slice(group.name, 0, 1) |> String.upcase() %></span>
                </div>
                <div class="flex-1">
                  <div class="flex justify-between items-baseline">
                    <h3 class="font-medium text-onyx-deep"><%= group.name %></h3>
                    <span class="text-xs text-onyx-mauve"><%= Calendar.strftime(group.updated_at, "%H:%M") %></span>
                  </div>
                  <p class="text-sm text-onyx-mauve truncate"><%= group.description || "Tap to start chatting" %></p>
                </div>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Chat Area (WhatsApp-like) -->
      <div class="flex-1 flex flex-col bg-gradient-to-b from-onyx-mauve/5 to-onyx mt-24">
        <%= if @selected_group do %>
          <!-- Chat Header -->
          <div class="bg-white border-b border-onyx-mauve/20 p-4 sticky top-0 z-10">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-full bg-verdant-forest/10 flex items-center justify-center">
                <span class="text-verdant-forest font-semibold"><%= String.slice(@selected_group.name, 0, 1) |> String.upcase() %></span>
              </div>
              <div>
                <h2 class="text-lg font-semibold text-onyx-deep"><%= @selected_group.name %></h2>
                <p class="text-xs text-onyx-mauve">online • <%= length(@messages) %> messages</p>
              </div>
            </div>
          </div>

          <!-- Messages Container -->
          <div class="flex-1 overflow-y-auto p-4 space-y-2" id="messages-container" phx-hook="ScrollToBottom">
            <%= for message <- @messages do %>
              <div class={[
                "flex",
                message.user_id == @current_user_id && "justify-end",
                message.user_id != @current_user_id && "justify-start"
              ]}>
                <div class={[
                  "max-w-[70%] rounded-2xl px-4 py-2",
                  message.user_id == @current_user_id && "bg-verdant-forest text-white",
                  message.user_id != @current_user_id && "bg-white text-onyx-deep shadow-sm"
                ]}>
                  <p class="text-sm"><%= message.content %></p>
                  <div class="flex items-center gap-1 mt-1">
                    <p class="text-xs opacity-60">
                      <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                    </p>
                    <%= if message.is_edited do %>
                      <span class="text-xs opacity-60">(edited)</span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Input Area (WhatsApp-style) -->
          <div class="border-t border-onyx-mauve/20 p-4 bg-white">
            <div class="flex items-center gap-2">
              <!-- Attachment Button -->
              <button class="text-verdant-forest hover:text-verdant-deep">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              </button>
              
              <!-- Camera Button -->
              <button class="text-verdant-forest hover:text-verdant-deep">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z" />
                </svg>
              </button>
              
              <!-- Text Input -->
              <input
                type="text"
                name="message"
                value={@input_text}
                phx-change="update-input"
                placeholder="Type a message..."
                class="flex-1 bg-onyx-mauve/5 border border-onyx-mauve/20 rounded-full px-5 py-3 text-onyx-deep placeholder-onyx-mauve focus:outline-none focus:border-verdant-forest"
              />
              
              <!-- Send Button -->
              <button
                phx-click="send_message"
                class="bg-verdant-forest hover:bg-verdant-deep text-white rounded-full p-3 transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </div>
          </div>
        <% else %>
          <!-- Empty State -->
          <div class="flex-1 flex items-center justify-center">
            <div class="text-center">
              <svg class="w-20 h-20 mx-auto text-onyx-mauve" fill="none" stroke="currentColor" stroke-width="1" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />
              </svg>
              <p class="text-onyx-deep mt-4 font-medium">Select a chat</p>
              <p class="text-sm text-onyx-mauve mt-1">Choose a conversation to start messaging</p>
              <button phx-click="new_group" class="mt-4 text-verdant-forest hover:underline">
                Or create a new group
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Create Group Modal -->
    <%= if @show_form do %>
      <div class="fixed inset-0 bg-onyx-deep/50 flex items-center justify-center z-50">
        <div class="bg-white rounded-2xl p-6 max-w-md w-full mx-4">
          <h2 class="text-xl font-semibold text-onyx-deep mb-4">Create New Group</h2>
          <form phx-submit="create_group" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-onyx-deep mb-1">Group Name</label>
              <input
                type="text"
                name="name"
                class="w-full px-4 py-2 border border-onyx-mauve/30 rounded-lg focus:outline-none focus:border-verdant-forest"
                required
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-onyx-deep mb-1">Description</label>
              <textarea
                name="description"
                rows="3"
                class="w-full px-4 py-2 border border-onyx-mauve/30 rounded-lg focus:outline-none focus:border-verdant-forest"
              ></textarea>
            </div>
            <div class="flex gap-3 pt-2">
              <button type="button" phx-click="close_form" class="flex-1 px-4 py-2 border border-onyx-mauve/20 rounded-lg text-onyx-deep hover:bg-onyx-mauve/5">
                Cancel
              </button>
              <button type="submit" class="flex-1 bg-verdant-forest text-white py-2 rounded-lg hover:bg-verdant-deep">
                Create
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <!-- Status Upload Modal -->
    <%= if @show_status_modal do %>
      <div class="fixed inset-0 bg-onyx-deep/50 flex items-center justify-center z-50">
        <div class="bg-white rounded-2xl p-6 max-w-md w-full mx-4">
          <h2 class="text-xl font-semibold text-onyx-deep mb-4">Add Status</h2>
          <div class="space-y-4">
            <div class="border-2 border-dashed border-onyx-mauve/30 rounded-xl p-8 text-center">
              <svg class="w-12 h-12 mx-auto text-onyx-mauve" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 16.5V9.75m0 0l3 3m-3-3l-3 3M6.75 19.5a4.5 4.5 0 01-1.41-8.775 5.25 5.25 0 0110.233-2.33 3 3 0 013.758 3.848A3.752 3.752 0 0118 19.5H6.75z" />
              </svg>
              <p class="text-onyx-mauve mt-2">Tap to upload photo or video</p>
              <input type="file" accept="image/*,video/*" class="hidden" id="status-media" />
            </div>
            <div>
              <label class="block text-sm font-medium text-onyx-deep mb-1">Caption (optional)</label>
              <textarea rows="2" class="w-full px-4 py-2 border border-onyx-mauve/30 rounded-lg focus:outline-none focus:border-verdant-forest"></textarea>
            </div>
            <div class="flex gap-3">
              <button phx-click="close_status_modal" class="flex-1 px-4 py-2 border border-onyx-mauve/20 rounded-lg text-onyx-deep hover:bg-onyx-mauve/5">
                Cancel
              </button>
              <button class="flex-1 bg-verdant-forest text-white py-2 rounded-lg hover:bg-verdant-deep">
                Share Status
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end