defmodule MtaaniWeb.TripLive do
  use MtaaniWeb, :live_view
  alias Mtaani.Plan
  alias Mtaani.Plan.{Trip, ItineraryItem, BudgetItem, PackingItem, VibePin}
  alias Mtaani.Accounts
  alias Mtaani.Groups
  alias Mtaani.Chat

  @impl true
  def mount(%{"id" => trip_id}, _session, socket) do
    current_user = socket.assigns.current_user

    # Load trip data from database (NO HARDCODED DATA)
    trip = Plan.get_trip!(String.to_integer(trip_id))

    # Check if user is participant
    participant = Plan.get_participant(trip.id, current_user.id)

    if is_nil(participant) do
      {:ok, push_navigate(socket, to: "/plan")}
    else
      # Load all trip data from database
      itinerary_items = Plan.list_itinerary_items(trip.id)
      budget_summary = Plan.get_budget_summary(trip.id)
      packing_items = Plan.list_packing_items(trip.id)
      vibe_pins = Plan.list_vibe_pins(trip.id)
      participants = Plan.get_trip_participants(trip.id)

      # Load chat messages from database if group exists
      chat_messages = load_chat_messages(trip)

      # Subscribe to real-time updates
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "trip:#{trip.id}")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "trip_votes:#{trip.id}")
        Phoenix.PubSub.subscribe(Mtaani.PubSub, "trip_chat:#{trip.id}")
      end

      online_count =
        Enum.count(participants, fn p ->
          p.user && p.user.last_active &&
            DateTime.diff(DateTime.utc_now(), p.user.last_active, :minute) < 5
        end)

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:trip, trip)
        |> assign(:participant, participant)
        |> assign(:participants, participants)
        |> assign(:itinerary_items, itinerary_items)
        |> assign(:budget_summary, budget_summary)
        |> assign(:packing_items, packing_items)
        |> assign(:vibe_pins, vibe_pins)
        |> assign(:chat_messages, chat_messages)
        |> assign(:selected_subtab, "itinerary")
        |> assign(:new_message, "")
        |> assign(:show_add_item_modal, false)
        |> assign(:show_add_budget_modal, false)
        |> assign(:show_add_pin_modal, false)
        |> assign(:new_item_type, "activity")
        |> assign(:new_item_title, "")
        |> assign(:new_item_time, nil)
        |> assign(:new_item_cost, 0)
        |> assign(:new_item_day, 1)
        |> assign(:new_budget_category, "accommodation")
        |> assign(:new_budget_description, "")
        |> assign(:new_budget_amount, 0)
        |> assign(:new_pin_emoji, "📸")
        |> assign(:new_pin_caption, "")
        |> assign(:online_count, online_count)

      {:ok, socket}
    end
  end

  # Real-time updates
  @impl true
  def handle_info({:itinerary_updated, _item}, socket) do
    itinerary_items = Plan.list_itinerary_items(socket.assigns.trip.id)
    {:noreply, assign(socket, :itinerary_items, itinerary_items)}
  end

  @impl true
  def handle_info({:vote_updated, item_id, votes_count}, socket) do
    items =
      Enum.map(socket.assigns.itinerary_items, fn {day, items} ->
        {day,
         Enum.map(items, fn item ->
           if item.id == item_id, do: %{item | votes_count: votes_count}, else: item
         end)}
      end)

    {:noreply, assign(socket, :itinerary_items, items)}
  end

  @impl true
  def handle_info({:budget_updated, trip_id}, socket) do
    budget_summary = Plan.get_budget_summary(trip_id)
    {:noreply, assign(socket, :budget_summary, budget_summary)}
  end

  @impl true
  def handle_info({:packing_updated, _trip_id}, socket) do
    packing_items = Plan.list_packing_items(socket.assigns.trip.id)
    {:noreply, assign(socket, :packing_items, packing_items)}
  end

  @impl true
  def handle_info({:new_chat_message, message}, socket) do
    messages = [message | socket.assigns.chat_messages]
    {:noreply, assign(socket, :chat_messages, messages)}
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    participants = [participant | socket.assigns.participants]

    online_count =
      Enum.count(participants, fn p ->
        p.user && p.user.last_active &&
          DateTime.diff(DateTime.utc_now(), p.user.last_active, :minute) < 5
      end)

    {:noreply,
     socket
     |> assign(:participants, participants)
     |> assign(:online_count, online_count)}
  end

  # Subtab switching
  @impl true
  def handle_event("switch_subtab", %{"tab" => tab}, socket) do
    socket =
      case tab do
        "budget" ->
          assign(socket, :budget_summary, Plan.get_budget_summary(socket.assigns.trip.id))

        "packing" ->
          assign(socket, :packing_items, Plan.list_packing_items(socket.assigns.trip.id))

        "vibe" ->
          assign(socket, :vibe_pins, Plan.list_vibe_pins(socket.assigns.trip.id))

        "chat" ->
          assign(socket, :chat_messages, load_chat_messages(socket.assigns.trip))

        _ ->
          socket
      end

    {:noreply, assign(socket, :selected_subtab, tab)}
  end

  # Itinerary: Add Item
  @impl true
  def handle_event("open_add_item", _params, socket) do
    {:noreply, assign(socket, :show_add_item_modal, true)}
  end

  @impl true
  def handle_event("close_add_item", _params, socket) do
    {:noreply, assign(socket, :show_add_item_modal, false)}
  end

  @impl true
  def handle_event("update_new_item", %{"field" => "title", "value" => value}, socket) do
    {:noreply, assign(socket, :new_item_title, value)}
  end

  @impl true
  def handle_event("update_new_item", %{"field" => "time", "value" => value}, socket) do
    {:noreply, assign(socket, :new_item_time, value)}
  end

  @impl true
  def handle_event("update_new_item", %{"field" => "cost", "value" => value}, socket) do
    cost =
      case Integer.parse(value) do
        {num, ""} -> num
        _ -> 0
      end

    {:noreply, assign(socket, :new_item_cost, cost)}
  end

  @impl true
  def handle_event("update_new_item", %{"field" => "day", "value" => value}, socket) do
    day =
      case Integer.parse(value) do
        {num, ""} -> num
        _ -> 1
      end

    {:noreply, assign(socket, :new_item_day, day)}
  end

  @impl true
  def handle_event("select_item_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :new_item_type, type)}
  end

  @impl true
  def handle_event("create_itinerary_item", _params, socket) do
    attrs = %{
      trip_id: socket.assigns.trip.id,
      day_number: socket.assigns.new_item_day,
      title: socket.assigns.new_item_title,
      type: socket.assigns.new_item_type,
      start_time: socket.assigns.new_item_time,
      cost: socket.assigns.new_item_cost,
      status: "pending"
    }

    case Plan.create_itinerary_item(attrs) do
      {:ok, item} ->
        Phoenix.PubSub.broadcast(
          Mtaani.PubSub,
          "trip:#{socket.assigns.trip.id}",
          {:itinerary_updated, item}
        )

        itinerary_items = Plan.list_itinerary_items(socket.assigns.trip.id)

        {:noreply,
         socket
         |> assign(:itinerary_items, itinerary_items)
         |> assign(:show_add_item_modal, false)
         |> assign(:new_item_title, "")
         |> assign(:new_item_time, nil)
         |> assign(:new_item_cost, 0)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add item")}
    end
  end

  # Voting on itinerary items
  @impl true
  def handle_event("vote_item", %{"item_id" => item_id}, socket) do
    case Plan.vote_on_item(String.to_integer(item_id), socket.assigns.current_user.id) do
      {:ok, _vote} ->
        {:noreply, socket}

      {:ok, :removed} ->
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # Budget: Add Expense
  @impl true
  def handle_event("open_add_budget", _params, socket) do
    {:noreply, assign(socket, :show_add_budget_modal, true)}
  end

  @impl true
  def handle_event("close_add_budget", _params, socket) do
    {:noreply, assign(socket, :show_add_budget_modal, false)}
  end

  @impl true
  def handle_event("update_budget_field", %{"field" => "category", "value" => value}, socket) do
    {:noreply, assign(socket, :new_budget_category, value)}
  end

  @impl true
  def handle_event("update_budget_field", %{"field" => "description", "value" => value}, socket) do
    {:noreply, assign(socket, :new_budget_description, value)}
  end

  @impl true
  def handle_event("update_budget_field", %{"field" => "amount", "value" => value}, socket) do
    amount =
      case Integer.parse(value) do
        {num, ""} -> num
        _ -> 0
      end

    {:noreply, assign(socket, :new_budget_amount, amount)}
  end

  @impl true
  def handle_event("create_budget_item", _params, socket) do
    attrs = %{
      trip_id: socket.assigns.trip.id,
      category: socket.assigns.new_budget_category,
      description: socket.assigns.new_budget_description,
      amount: socket.assigns.new_budget_amount,
      paid_by_id: socket.assigns.current_user.id,
      expense_date: Date.utc_today()
    }

    case Plan.create_budget_item(attrs) do
      {:ok, _item} ->
        budget_summary = Plan.get_budget_summary(socket.assigns.trip.id)

        Phoenix.PubSub.broadcast(
          Mtaani.PubSub,
          "trip:#{socket.assigns.trip.id}",
          {:budget_updated, socket.assigns.trip.id}
        )

        {:noreply,
         socket
         |> assign(:budget_summary, budget_summary)
         |> assign(:show_add_budget_modal, false)
         |> assign(:new_budget_description, "")
         |> assign(:new_budget_amount, 0)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add expense")}
    end
  end

  # Packing: Toggle Items
  @impl true
  def handle_event("toggle_packing_item", %{"item_id" => item_id}, socket) do
    case Plan.toggle_packing_item(String.to_integer(item_id)) do
      {:ok, _item} ->
        packing_items = Plan.list_packing_items(socket.assigns.trip.id)

        Phoenix.PubSub.broadcast(
          Mtaani.PubSub,
          "trip:#{socket.assigns.trip.id}",
          {:packing_updated, socket.assigns.trip.id}
        )

        {:noreply, assign(socket, :packing_items, packing_items)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("generate_ai_packing", _params, socket) do
    packing_items = Plan.generate_ai_packing_list(socket.assigns.trip.id)
    {:noreply, assign(socket, :packing_items, packing_items)}
  end

  # Vibe Board: Add Pin
  @impl true
  def handle_event("open_add_pin", _params, socket) do
    {:noreply, assign(socket, :show_add_pin_modal, true)}
  end

  @impl true
  def handle_event("close_add_pin", _params, socket) do
    {:noreply, assign(socket, :show_add_pin_modal, false)}
  end

  @impl true
  def handle_event("update_pin_field", %{"field" => "emoji", "value" => value}, socket) do
    {:noreply, assign(socket, :new_pin_emoji, value)}
  end

  @impl true
  def handle_event("update_pin_field", %{"field" => "caption", "value" => value}, socket) do
    {:noreply, assign(socket, :new_pin_caption, value)}
  end

  @impl true
  def handle_event("create_vibe_pin", _params, socket) do
    attrs = %{
      trip_id: socket.assigns.trip.id,
      user_id: socket.assigns.current_user.id,
      emoji: socket.assigns.new_pin_emoji,
      caption: socket.assigns.new_pin_caption
    }

    case Plan.create_vibe_pin(attrs) do
      {:ok, _pin} ->
        vibe_pins = Plan.list_vibe_pins(socket.assigns.trip.id)

        {:noreply,
         socket
         |> assign(:vibe_pins, vibe_pins)
         |> assign(:show_add_pin_modal, false)
         |> assign(:new_pin_caption, "")
         |> assign(:new_pin_emoji, "📸")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add pin")}
    end
  end

  # Chat: Send Message
  @impl true
  def handle_event("update_new_message", %{"value" => value}, socket) do
    {:noreply, assign(socket, :new_message, value)}
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    if String.trim(socket.assigns.new_message) != "" do
      trip = socket.assigns.trip

      if trip.group_id do
        case Groups.get_group(trip.group_id) do
          nil ->
            {:noreply, socket}

          group ->
            case Groups.get_channel_by_name(group.id, "general") do
              nil ->
                {:noreply, socket}

              channel ->
                case Groups.create_channel_message(
                       %{content: socket.assigns.new_message},
                       socket.assigns.current_user.id,
                       group.id,
                       channel.id
                     ) do
                  {:ok, message} ->
                    Phoenix.PubSub.broadcast(
                      Mtaani.PubSub,
                      "trip_chat:#{trip.id}",
                      {:new_chat_message, message}
                    )

                    {:noreply, assign(socket, :new_message, "")}

                  _ ->
                    {:noreply, socket}
                end
            end
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Invite users
  @impl true
  def handle_event("invite_user", _params, socket) do
    {:noreply, put_flash(socket, :info, "Share this trip link with friends to invite them!")}
  end

  # Navigation
  @impl true
  def handle_event("back_to_plan", _params, socket) do
    {:noreply, push_navigate(socket, to: "/plan")}
  end

  defp load_chat_messages(trip) do
    if trip.group_id do
      case Groups.get_group(trip.group_id) do
        nil ->
          []

        group ->
          case Groups.get_channel_by_name(group.id, "general") do
            nil -> []
            channel -> Groups.get_channel_messages(channel.id, 50)
          end
      end
    else
      []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="trip-page-wrapper">
      <div class="pb-20">
        <.trip_header
          trip={@trip}
          participants={@participants}
          online_count={@online_count}
          back_to_plan="back_to_plan"
          invite_user="invite_user"
        /> <.sub_tabs selected={@selected_subtab} switch_subtab="switch_subtab" />
        <%= if @selected_subtab == "itinerary" do %>
          <.itinerary_tab
            itinerary_items={@itinerary_items}
            trip={@trip}
            show_add_item_modal={@show_add_item_modal}
            new_item_title={@new_item_title}
            new_item_type={@new_item_type}
            new_item_day={@new_item_day}
            new_item_time={@new_item_time}
            new_item_cost={@new_item_cost}
            open_add_item="open_add_item"
            close_add_item="close_add_item"
            update_new_item="update_new_item"
            select_item_type="select_item_type"
            create_itinerary_item="create_itinerary_item"
            vote_item="vote_item"
          />
        <% end %>
        
        <%= if @selected_subtab == "budget" do %>
          <.budget_tab
            budget_summary={@budget_summary}
            trip={@trip}
            participants={@participants}
            current_user={@current_user}
            show_add_budget_modal={@show_add_budget_modal}
            new_budget_category={@new_budget_category}
            new_budget_description={@new_budget_description}
            new_budget_amount={@new_budget_amount}
            open_add_budget="open_add_budget"
            close_add_budget="close_add_budget"
            update_budget_field="update_budget_field"
            create_budget_item="create_budget_item"
          />
        <% end %>
        
        <%= if @selected_subtab == "transport" do %>
          <.transport_tab />
        <% end %>
        
        <%= if @selected_subtab == "packing" do %>
          <.packing_tab
            packing_items={@packing_items}
            trip={@trip}
            toggle_packing_item="toggle_packing_item"
            generate_ai_packing="generate_ai_packing"
          />
        <% end %>
        
        <%= if @selected_subtab == "vibe" do %>
          <.vibe_tab
            vibe_pins={@vibe_pins}
            trip={@trip}
            show_add_pin_modal={@show_add_pin_modal}
            new_pin_emoji={@new_pin_emoji}
            new_pin_caption={@new_pin_caption}
            open_add_pin="open_add_pin"
            close_add_pin="close_add_pin"
            update_pin_field="update_pin_field"
            create_vibe_pin="create_vibe_pin"
          />
        <% end %>
        
        <%= if @selected_subtab == "chat" do %>
          <.chat_tab
            chat_messages={@chat_messages}
            current_user={@current_user}
            new_message={@new_message}
            update_new_message="update_new_message"
            send_message="send_message"
          />
        <% end %>
      </div>
    </div>
    """
  end

  # Component Functions

  def trip_header(assigns) do
    ~H"""
    <div class="itin-header">
      <div class="ih-cover" style="background: linear-gradient(135deg, #064e3b, #065f46)">
        <div class="trip-cover-emoji">{@trip.cover_emoji} 🌄</div>
         <button class="back-button" phx-click={@back_to_plan}>←</button>
        <button class="menu-button">⋯</button>
        <div class="ih-gradient"></div>
        
        <div class="ih-title">{@trip.name}</div>
        
        <div class="ih-sub">{length(@participants)} people</div>
      </div>
      
      <div class="itin-meta">
        <div class="im-left">
          <div class="im-dates">
            {format_date(@trip.start_date)} – {format_date(@trip.end_date)}, {Calendar.strftime(
              @trip.end_date,
              "%Y"
            )}
          </div>
          
          <div class="im-sub">
            <div class="collab-avs">
              <%= for participant <- Enum.take(@participants, 5) do %>
                <div class="co-av" style={"background: #{avatar_color(participant.user_id)}"}>
                  {initials(participant.user.name)}
                </div>
              <% end %>
            </div>
             <span>{length(@participants)} planners · {@online_count} online</span>
          </div>
        </div>
         <button class="invite-btn" phx-click={@invite_user}>＋ Invite</button>
      </div>
    </div>
    """
  end

  def sub_tabs(assigns) do
    ~H"""
    <div class="itin-tabs">
      <button
        class={"itab #{if @selected == "itinerary", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="itinerary"
      >
        📋 Itinerary
      </button>
      
      <button
        class={"itab #{if @selected == "budget", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="budget"
      >
        💰 Budget
      </button>
      
      <button
        class={"itab #{if @selected == "transport", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="transport"
      >
        🚐 Transport
      </button>
      
      <button
        class={"itab #{if @selected == "packing", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="packing"
      >
        🎒 Packing
      </button>
      
      <button
        class={"itab #{if @selected == "vibe", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="vibe"
      >
        🎨 Vibe board
      </button>
      
      <button
        class={"itab #{if @selected == "chat", do: "on"}"}
        phx-click={@switch_subtab}
        phx-value-tab="chat"
      >
        💬 Group chat
      </button>
    </div>
    """
  end

  def itinerary_tab(assigns) do
    ~H"""
    <div class="scrollable">
      <div class="ai-strip" style="margin-top: 12px">
        <div class="ai-icon">✦</div>
        
        <div class="ai-body">
          <div class="ai-title">AI suggested this itinerary</div>
          
          <div class="ai-sub">Based on your group vibe, budget, and local recommendations.</div>
          
          <div class="ai-action">Regenerate with different vibe →</div>
        </div>
      </div>
      
      <%= for {day, items} <- @itinerary_items do %>
        <div class="day-block">
          <div class="db-header">
            <div class="db-day">
              Day {day}
              <span class="db-date">
                {format_date(Date.add(@trip.start_date, day - 1))}
              </span>
            </div>
             <button class="db-add" phx-click={@open_add_item}>＋ Add stop</button>
          </div>
          
          <div class="timeline">
            <%= for item <- items do %>
              <div class="tl-item">
                <div class="tl-left">
                  <div class={"tl-dot #{item_type_class(item.type)}"}>
                    {item_type_icon(item.type)}
                  </div>
                  
                  <div class="tl-line"></div>
                </div>
                
                <div class="tl-right">
                  <div class="tl-time">
                    {format_time(item.start_time)} · {String.upcase(item.type)}
                  </div>
                  
                  <div class="tl-card">
                    <div class="tlc-top">
                      <div class="tlc-name">{item.title}</div>
                      
                      <span
                        class="tlc-tag"
                        style={"background: #{item_type_bg(item.type)}; color: #{item_type_text(item.type)}"}
                      >
                        {item_type_label(item.type)}
                      </span>
                    </div>
                    
                    <div class="tlc-meta">
                      📍 {item.location || "Location TBD"} · {item.duration_hours} hours
                    </div>
                    
                    <div class="tlc-footer">
                      <span class="tlc-price">
                        KSh {format_number(item.cost)}/person
                      </span>
                      
                      <div class="vote-row">
                        <button class="vote-btn" phx-click={@vote_item} phx-value-item_id={item.id}>
                          👍 <span id={"vote-count-#{item.id}"}>{item.votes_count || 0}</span>
                        </button>
                      </div>
                    </div>
                    
                    <%= if item.guide_id do %>
                      <div class="tlc-guide">
                        <div class="tg-av" style="background: #e11d48">NB</div>
                         <span class="tg-label">Led by local guide · Verified</span>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <div style="height: 20px"></div>
    </div>

    <%= if @show_add_item_modal do %>
      <.add_item_modal
        new_item_title={@new_item_title}
        new_item_type={@new_item_type}
        new_item_day={@new_item_day}
        new_item_time={@new_item_time}
        new_item_cost={@new_item_cost}
        close_add_item={@close_add_item}
        update_new_item={@update_new_item}
        select_item_type={@select_item_type}
        create_itinerary_item={@create_itinerary_item}
      />
    <% end %>
    """
  end

  def budget_tab(assigns) do
    ~H"""
    <div class="scrollable">
      <div style="padding: 14px 0">
        <div class="budget-bar">
          <div class="bb-top">
            <div class="bb-title">Trip budget · {@budget_summary.participant_count} people</div>
            
            <div class="bb-total">KSh {format_number(@budget_summary.total)} total</div>
          </div>
          
          <div class="bb-track">
            <div class="bb-fill" style={"width: #{budget_percentage(@budget_summary, @trip)}%"}></div>
          </div>
          
          <div style="display: flex; justify-content: space-between; margin-bottom: 10px">
            <div style="font-size: 11px; color: var(--color-text-secondary)">
              KSh {format_number(@budget_summary.total)} committed
            </div>
            
            <div style="font-size: 11px; color: #10b981; font-weight: 500">
              KSh {format_number(budget_remaining(@budget_summary, @trip))} remaining
            </div>
          </div>
          
          <div class="bb-cats">
            <%= for {category, amount} <- @budget_summary.categories do %>
              <%= if amount > 0 do %>
                <div class="bb-cat">
                  <div class="bcc" style={"background: #{category_color(category)}"}></div>
                   {category_label(category)} {percentage(amount, @budget_summary.total)}%
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
        <div class="sec">SPLIT BY PERSON</div>
        
        <div style="margin: 0 16px">
          <div class="budget-table">
            <div class="budget-table-header">
              <div>MEMBER</div>
              
              <div style="text-align: center">COMMITTED</div>
              
              <div style="text-align: right">STATUS</div>
            </div>
            
            <%= for participant <- @participants do %>
              <div class="budget-table-row">
                <div style="display: flex; align-items: center; gap: 8px">
                  <div
                    class="user-avatar-small"
                    style={"background: #{avatar_color(participant.user_id)}"}
                  >
                    {initials(participant.user.name)}
                  </div>
                  
                  <span>
                    <%= if participant.user_id == @current_user.id do %>
                      You
                    <% else %>
                      {participant.user.name}
                    <% end %>
                  </span>
                </div>
                
                <div style="text-align: center; font-weight: 500">
                  KSh {format_number(participant.committed_amount || 0)}
                </div>
                
                <div style="text-align: right">
                  <span class={"payment-badge #{participant.payment_status}"}>
                    {String.capitalize(participant.payment_status)}
                  </span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
        <button class="add-expense-btn" phx-click={@open_add_budget}>
          ＋ Add expense
        </button>
      </div>
    </div>

    <%= if @show_add_budget_modal do %>
      <.add_budget_modal
        new_budget_category={@new_budget_category}
        new_budget_description={@new_budget_description}
        new_budget_amount={@new_budget_amount}
        close_add_budget={@close_add_budget}
        update_budget_field={@update_budget_field}
        create_budget_item={@create_budget_item}
      />
    <% end %>
    """
  end

  def transport_tab(assigns) do
    ~H"""
    <div class="scrollable">
      <div style="padding: 14px 0">
        <div class="sec">RECOMMENDED OPTIONS</div>
        
        <div class="transport-card">
          <div class="trp-row">
            <div class="trp-icon">🚐</div>
            
            <div class="trp-info">
              <div class="trp-name">Safari minivan — Group transport</div>
              
              <div class="trp-meta">Nairobi · Departs 6:00 AM · Recommended</div>
            </div>
            
            <div class="trp-price">KSh 4,500</div>
          </div>
          
          <div class="trp-tags">
            <span class="trp-tag" style="background: #ecfdf5; color: #065f46">✅ Recommended</span>
            <span class="trp-tag" style="background: #eff6ff; color: #1e40af">7 seats</span>
          </div>
        </div>
        
        <div class="transport-card">
          <div class="trp-row">
            <div class="trp-icon">🚌</div>
            
            <div class="trp-info">
              <div class="trp-name">Premium shuttle service</div>
              
              <div class="trp-meta">Daily departures · 7:00 AM & 9:00 AM</div>
            </div>
            
            <div class="trp-price">KSh 800</div>
          </div>
          
          <div class="trp-tags">
            <span class="trp-tag" style="background: #f8fafc; color: #475569">Budget option</span>
            <span class="trp-tag" style="background: #eff6ff; color: #1e40af">WiFi included</span>
          </div>
        </div>
        
        <div class="transport-card">
          <div class="trp-row">
            <div class="trp-icon">🚂</div>
            
            <div class="trp-info">
              <div class="trp-name">SGR Madaraka Express</div>
              
              <div class="trp-meta">Nairobi Terminus · 3 departures daily</div>
            </div>
            
            <div class="trp-price">KSh 3,000</div>
          </div>
          
          <div class="trp-tags">
            <span class="trp-tag" style="background: #ecfdf5; color: #065f46">Scenic route</span>
            <span class="trp-tag" style="background: #f8fafc; color: #475569">4hrs 30min</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def packing_tab(assigns) do
    ~H"""
    <div class="scrollable">
      <div style="padding: 14px 0">
        <div class="sec">
          PACKING LIST <button class="see-all" phx-click={@generate_ai_packing}>✨ AI Generate</button>
        </div>
        
        <div style="margin: 0 16px 10px; font-size: 12px; color: var(--color-text-secondary)">
          Based on your {String.downcase(@trip.destination)} trip · {weather_suggestion(
            @trip.destination
          )} · {Date.diff(@trip.end_date, @trip.start_date)} days
        </div>
        
        <div class="pack-grid">
          <%= for item <- Enum.sort_by(@packing_items, &{&1.category, &1.order_index}) do %>
            <div class="pack-item" phx-click={@toggle_packing_item} phx-value-item_id={item.id}>
              <div class={"pi-check #{if item.is_checked, do: "done"}"}>
                {if item.is_checked, do: "✓"}
              </div>
              
              <span class={"pi-label #{if item.is_checked, do: "done"}"}>
                {item.name}
              </span>
            </div>
          <% end %>
        </div>
        
        <div class="ai-tip">
          ✦ AI tip: {ai_tip(@trip.destination)}
        </div>
      </div>
    </div>
    """
  end

  def vibe_tab(assigns) do
    ~H"""
    <div class="scrollable">
      <div style="padding: 14px 0">
        <div class="vibe-board">
          <div class="vb-header">
            <div class="vb-title">Trip vibe board</div>
             <button class="vb-add" phx-click={@open_add_pin}>＋ Add photo or pin</button>
          </div>
          
          <div class="vb-grid">
            <%= for pin <- @vibe_pins do %>
              <div class="vb-pin" style="background: #d1fae5">
                {pin.emoji}
              </div>
            <% end %>
            
            <button class="vb-add-pin" phx-click={@open_add_pin}>
              <span style="font-size: 22px">＋</span> <span>Add vibe</span>
            </button>
          </div>
        </div>
        
        <div class="sec">TRIP VIBE TAGS</div>
        
        <div class="vibe-tags">
          <%= for vibe <- @trip.vibe_tags do %>
            <span class="vibe-tag">{vibe}</span>
          <% end %>
        </div>
      </div>
    </div>

    <%= if @show_add_pin_modal do %>
      <.add_pin_modal
        new_pin_emoji={@new_pin_emoji}
        new_pin_caption={@new_pin_caption}
        close_add_pin={@close_add_pin}
        update_pin_field={@update_pin_field}
        create_vibe_pin={@create_vibe_pin}
      />
    <% end %>
    """
  end

  def chat_tab(assigns) do
    ~H"""
    <div class="chat-container">
      <div class="collab-chat">
        <div class="cc-header">
          <div class="cc-title">Trip planning chat</div>
          
          <div class="cc-open">Open full chat</div>
        </div>
        
        <div class="chat-messages" id="chat-messages">
          <%= for message <- Enum.reverse(@chat_messages) do %>
            <div class="cc-msg">
              <div class="cc-av" style={"background: #{avatar_color(message.user_id)}"}>
                {initials(message.user.name)}
              </div>
              
              <div class="cc-body">
                <div class="cc-name">{message.user.name}</div>
                
                <div class="cc-text">{message.content}</div>
              </div>
            </div>
          <% end %>
        </div>
        
        <div class="cc-input">
          <input
            class="cci"
            placeholder="Message the group..."
            value={@new_message}
            phx-keyup={@update_new_message}
            phx-key="Enter"
            id="chat-input"
          /> <button class="cc-send" phx-click={@send_message}>↑</button>
        </div>
      </div>
    </div>
    """
  end

  # Modal Components
  def add_item_modal(assigns) do
    ~H"""
    <div class="modal-bg open" phx-click={@close_add_item}>
      <div class="modal-sheet" phx-click-away={@close_add_item}>
        <div class="msh"></div>
        
        <div class="ms-title">Add to itinerary ✦</div>
        
        <div class="ms-body">
          <div class="ms-label">Item type</div>
          
          <div class="type-selector">
            <button
              class={"type-option #{if @new_item_type == "activity", do: "selected"}"}
              phx-click={@select_item_type}
              phx-value-type="activity"
            >
              🎭 Activity
            </button>
            
            <button
              class={"type-option #{if @new_item_type == "food", do: "selected"}"}
              phx-click={@select_item_type}
              phx-value-type="food"
            >
              🍽 Food
            </button>
            
            <button
              class={"type-option #{if @new_item_type == "stay", do: "selected"}"}
              phx-click={@select_item_type}
              phx-value-type="stay"
            >
              🏨 Stay
            </button>
            
            <button
              class={"type-option #{if @new_item_type == "transport", do: "selected"}"}
              phx-click={@select_item_type}
              phx-value-type="transport"
            >
              🚐 Transport
            </button>
          </div>
          
          <div class="ms-label">Title</div>
          
          <input
            class="ms-input"
            placeholder="e.g., Maasai Mara Game Drive"
            value={@new_item_title}
            phx-blur={@update_new_item}
            phx-value-field="title"
          />
          <div class="ms-label">Day</div>
          
          <input
            class="ms-input"
            type="number"
            min="1"
            value={@new_item_day}
            phx-blur={@update_new_item}
            phx-value-field="day"
          />
          <div class="ms-label">Time (optional)</div>
          
          <input
            class="ms-input"
            type="time"
            value={@new_item_time}
            phx-blur={@update_new_item}
            phx-value-field="time"
          />
          <div class="ms-label">Estimated cost (KSh)</div>
          
          <input
            class="ms-input"
            type="number"
            placeholder="0"
            value={@new_item_cost}
            phx-blur={@update_new_item}
            phx-value-field="cost"
          /> <button class="create-btn" phx-click={@create_itinerary_item}>Add to itinerary</button>
        </div>
      </div>
    </div>
    """
  end

  def add_budget_modal(assigns) do
    ~H"""
    <div class="modal-bg open" phx-click={@close_add_budget}>
      <div class="modal-sheet" phx-click-away={@close_add_budget}>
        <div class="msh"></div>
        
        <div class="ms-title">Add expense ✦</div>
        
        <div class="ms-body">
          <div class="ms-label">Category</div>
          
          <div class="category-selector">
            <button
              class={"cat-option #{if @new_budget_category == "accommodation", do: "selected"}"}
              phx-click={@update_budget_field}
              phx-value-field="category"
              phx-value-value="accommodation"
            >
              🏨 Accommodation
            </button>
            
            <button
              class={"cat-option #{if @new_budget_category == "activities", do: "selected"}"}
              phx-click={@update_budget_field}
              phx-value-field="category"
              phx-value-value="activities"
            >
              🎭 Activities
            </button>
            
            <button
              class={"cat-option #{if @new_budget_category == "food", do: "selected"}"}
              phx-click={@update_budget_field}
              phx-value-field="category"
              phx-value-value="food"
            >
              🍽 Food
            </button>
            
            <button
              class={"cat-option #{if @new_budget_category == "transport", do: "selected"}"}
              phx-click={@update_budget_field}
              phx-value-field="category"
              phx-value-value="transport"
            >
              🚐 Transport
            </button>
          </div>
          
          <div class="ms-label">Description</div>
          
          <input
            class="ms-input"
            placeholder="e.g., Hotel booking"
            value={@new_budget_description}
            phx-blur={@update_budget_field}
            phx-value-field="description"
          />
          <div class="ms-label">Amount (KSh)</div>
          
          <input
            class="ms-input"
            type="number"
            placeholder="0"
            value={@new_budget_amount}
            phx-blur={@update_budget_field}
            phx-value-field="amount"
          /> <button class="create-btn" phx-click={@create_budget_item}>Add expense</button>
        </div>
      </div>
    </div>
    """
  end

  def add_pin_modal(assigns) do
    ~H"""
    <div class="modal-bg open" phx-click={@close_add_pin}>
      <div class="modal-sheet" phx-click-away={@close_add_pin}>
        <div class="msh"></div>
        
        <div class="ms-title">Add vibe pin ✦</div>
        
        <div class="ms-body">
          <div class="ms-label">Emoji / Icon</div>
          
          <input
            class="ms-input"
            placeholder="📸 🌅 🦁"
            value={@new_pin_emoji}
            phx-blur={@update_pin_field}
            phx-value-field="emoji"
          />
          <div class="ms-label">Caption (optional)</div>
          
          <input
            class="ms-input"
            placeholder="What's the vibe?"
            value={@new_pin_caption}
            phx-blur={@update_pin_field}
            phx-value-field="caption"
          /> <button class="create-btn" phx-click={@create_vibe_pin}>Add to vibe board</button>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions
  defp format_date(date) do
    Calendar.strftime(date, "%b %d")
  end

  defp format_time(nil), do: "Flexible"

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  defp format_number(nil), do: "0"
  defp format_number(num), do: Number.delimit(num)

  defp initials(nil), do: "??"

  defp initials(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp avatar_color(user_id) do
    colors = ["#e11d48", "#3b82f6", "#8b5cf6", "#f59e0b", "#10b981", "#6366f1"]
    Enum.at(colors, rem(user_id, length(colors)))
  end

  defp item_type_icon("transport"), do: "🚐"
  defp item_type_icon("activity"), do: "🎭"
  defp item_type_icon("food"), do: "🍽"
  defp item_type_icon("stay"), do: "🏨"
  defp item_type_icon("exploration"), do: "🥾"
  defp item_type_icon(_), do: "📍"

  defp item_type_class("transport"), do: "td-transport"
  defp item_type_class("activity"), do: "td-activity"
  defp item_type_class("food"), do: "td-eat"
  defp item_type_class("stay"), do: "td-stay"
  defp item_type_class("exploration"), do: "td-explore"
  defp item_type_class(_), do: "td-activity"

  defp item_type_label("transport"), do: "Transport"
  defp item_type_label("activity"), do: "Activity"
  defp item_type_label("food"), do: "Food & Drink"
  defp item_type_label("stay"), do: "Accommodation"
  defp item_type_label("exploration"), do: "Explore"
  defp item_type_label(_), do: "Activity"

  defp item_type_bg("transport"), do: "#fdf4ff"
  defp item_type_bg("activity"), do: "#fef2f2"
  defp item_type_bg("food"), do: "#fff7ed"
  defp item_type_bg("stay"), do: "#ecfdf5"
  defp item_type_bg("exploration"), do: "#eff6ff"
  defp item_type_bg(_), do: "#fef2f2"

  defp item_type_text("transport"), do: "#6b21a8"
  defp item_type_text("activity"), do: "#dc2626"
  defp item_type_text("food"), do: "#c2410c"
  defp item_type_text("stay"), do: "#065f46"
  defp item_type_text("exploration"), do: "#1e40af"
  defp item_type_text(_), do: "#dc2626"

  defp budget_percentage(budget_summary, trip) do
    if trip.budget_per_person && trip.budget_per_person > 0 do
      total_budget = trip.budget_per_person * budget_summary.participant_count
      if total_budget > 0, do: round(budget_summary.total / total_budget * 100), else: 0
    else
      0
    end
  end

  defp budget_remaining(budget_summary, trip) do
    if trip.budget_per_person && trip.budget_per_person > 0 do
      total_budget = trip.budget_per_person * budget_summary.participant_count
      max(0, total_budget - budget_summary.total)
    else
      0
    end
  end

  defp category_color("accommodation"), do: "#10b981"
  defp category_color("activities"), do: "#3b82f6"
  defp category_color("food"), do: "#f59e0b"
  defp category_color("transport"), do: "#8b5cf6"
  defp category_color(_), do: "#e11d48"

  defp category_label("accommodation"), do: "Accommodation"
  defp category_label("activities"), do: "Activities"
  defp category_label("food"), do: "Food"
  defp category_label("transport"), do: "Transport"
  defp category_label(_), do: "Other"

  defp percentage(amount, total) when total > 0 do
    round(amount / total * 100)
  end

  defp percentage(_, _), do: 0

  defp weather_suggestion(destination) do
    cond do
      String.contains?(destination, "Mara") -> "Apr · Warm days, cool nights"
      String.contains?(destination, "Beach") -> "Warm and humid"
      String.contains?(destination, "Mountain") -> "Cool mornings, sunny afternoons"
      true -> "Pleasant weather expected"
    end
  end

  defp ai_tip(destination) do
    cond do
      String.contains?(destination, "Mara") ->
        "Mornings can be chilly on safari drives - pack a fleece jacket!"

      String.contains?(destination, "Beach") ->
        "Don't forget reef-safe sunscreen and insect repellent"

      String.contains?(destination, "Mountain") ->
        "Layer up! Mountain weather can change quickly"

      true ->
        "Stay hydrated and bring sun protection"
    end
  end
end
