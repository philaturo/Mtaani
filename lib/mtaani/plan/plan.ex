# lib/mtaani/plan/plan.ex (COMPLETE FIXED VERSION)
defmodule Mtaani.Plan do
  @moduledoc """
  The Plan context for managing trips, itineraries, budgets, and packing.
  """

  import Ecto.Query, warn: false
  alias Mtaani.Repo
  alias Mtaani.Accounts.User
  alias Mtaani.Places.Place
  alias Mtaani.Groups
  alias Mtaani.Chat

  alias Mtaani.Plan.{
    Trip,
    TripParticipant,
    ItineraryItem,
    ItineraryVote,
    BudgetItem,
    PackingItem,
    VibePin
  }

  # ==================== Trip CRUD ====================

  def list_user_trips(user_id) do
    query =
      from(t in Trip,
        join: tp in TripParticipant,
        on: tp.trip_id == t.id,
        where: tp.user_id == ^user_id,
        order_by: [desc: t.start_date],
        preload: [:creator, participants: [:user]]
      )

    Repo.all(query)
    |> Enum.map(&enrich_trip/1)
  end

  def get_trip!(id) do
    Repo.get!(Trip, id)
    |> Repo.preload([
      :creator,
      :destination_place,
      :group,
      participants: [:user],
      itinerary_items: [:guide],
      budget_items: [:paid_by],
      packing_items: [],
      vibe_pins: [:user]
    ])
    |> enrich_trip()
  end

  def get_trip(id) do
    case Repo.get(Trip, id) do
      nil -> nil
      trip -> get_trip!(trip.id)
    end
  end

  def create_trip(attrs, creator_id) do
    # Create group for trip collaboration
    group_attrs = %{
      name: attrs["name"] <> " Trip Group",
      description: "Planning group for #{attrs["name"]}",
      type: "trip",
      created_by: creator_id,
      is_active: true
    }

    case Groups.create_group(group_attrs, creator_id) do
      {:ok, group} ->
        # Create trip with group_id
        trip_attrs = Map.put(attrs, "group_id", group.id)

        %Trip{}
        |> Trip.changeset(Map.put(trip_attrs, "creator_id", creator_id))
        |> Repo.insert()
        |> case do
          {:ok, trip} ->
            # Add creator as admin participant
            add_participant(trip.id, creator_id, "admin")
            # Create trip chat conversation
            create_trip_chat(trip)
            {:ok, trip}

          error ->
            error
        end

      error ->
        error
    end
  end

  def update_trip(%Trip{} = trip, attrs) do
    trip
    |> Trip.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, enrich_trip(updated)}
      error -> error
    end
  end

  def delete_trip(%Trip{} = trip) do
    # Optionally delete associated group
    if trip.group_id do
      case Groups.get_group(trip.group_id) do
        nil -> :ok
        group -> Groups.delete_group(group)
      end
    end

    Repo.delete(trip)
  end

  # ==================== Trip Participants ====================

  def add_participant(trip_id, user_id, role \\ "member") do
    case get_participant(trip_id, user_id) do
      nil ->
        %TripParticipant{}
        |> TripParticipant.changeset(%{
          trip_id: trip_id,
          user_id: user_id,
          role: role
        })
        |> Repo.insert()
        |> case do
          {:ok, participant} ->
            # Add user to trip group
            trip = get_trip!(trip_id)

            if trip.group_id do
              Groups.add_member(trip.group_id, user_id, role)
            end

            # Add user to trip chat
            add_to_trip_chat(trip, user_id)
            {:ok, participant}

          error ->
            error
        end

      participant ->
        {:ok, participant}
    end
  end

  def remove_participant(trip_id, user_id) do
    case get_participant(trip_id, user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        Repo.delete(participant)
        # Remove from trip group
        trip = get_trip!(trip_id)

        if trip.group_id do
          Groups.remove_member(trip.group_id, user_id)
        end

        # Remove from trip chat
        remove_from_trip_chat(trip, user_id)
    end
  end

  def get_participant(trip_id, user_id) do
    Repo.get_by(TripParticipant, trip_id: trip_id, user_id: user_id)
  end

  def get_trip_participants(trip_id) do
    query =
      from(tp in TripParticipant,
        where: tp.trip_id == ^trip_id,
        preload: [:user],
        order_by: [desc: tp.role, asc: tp.inserted_at]
      )

    Repo.all(query)
  end

  # ==================== Itinerary Items ====================

  def list_itinerary_items(trip_id) do
    query =
      from(i in ItineraryItem,
        where: i.trip_id == ^trip_id,
        order_by: [asc: i.day_number, asc: i.order_index, asc: i.start_time],
        preload: [:guide]
      )

    Repo.all(query)
    |> Enum.group_by(& &1.day_number)
  end

  def create_itinerary_item(attrs) do
    %ItineraryItem{}
    |> ItineraryItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_itinerary_item(%ItineraryItem{} = item, attrs) do
    item
    |> ItineraryItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_itinerary_item(%ItineraryItem{} = item) do
    Repo.delete(item)
  end

  # ==================== Voting System ====================

  def vote_on_item(item_id, user_id, vote_type \\ "up") do
    case get_user_vote(item_id, user_id) do
      nil ->
        # Create new vote
        %ItineraryVote{}
        |> ItineraryVote.changeset(%{
          itinerary_item_id: item_id,
          user_id: user_id,
          vote_type: vote_type
        })
        |> Repo.insert()
        |> case do
          {:ok, vote} ->
            update_vote_count(item_id)
            # Mark participant as voted
            mark_participant_voted(item_id, user_id)
            {:ok, vote}

          error ->
            error
        end

      vote ->
        # Update or remove vote
        if vote.vote_type == vote_type do
          # Remove vote (toggle off)
          Repo.delete(vote)
          update_vote_count(item_id)
          {:ok, :removed}
        else
          # Change vote type
          vote
          |> ItineraryVote.changeset(%{vote_type: vote_type})
          |> Repo.update()
          |> case do
            {:ok, updated} ->
              update_vote_count(item_id)
              {:ok, updated}

            error ->
              error
          end
        end
    end
  end

  def get_user_vote(item_id, user_id) do
    Repo.get_by(ItineraryVote, itinerary_item_id: item_id, user_id: user_id)
  end

  defp update_vote_count(item_id) do
    query = from(v in ItineraryVote, where: v.itinerary_item_id == ^item_id)
    count = Repo.aggregate(query, :count, :id)

    from(i in ItineraryItem, where: i.id == ^item_id)
    |> Repo.update_all(set: [votes_count: count])
  end

  defp mark_participant_voted(item_id, user_id) do
    # Get trip_id from itinerary item
    case Repo.get(ItineraryItem, item_id) do
      nil ->
        :ok

      item ->
        from(tp in TripParticipant,
          where: tp.trip_id == ^item.trip_id and tp.user_id == ^user_id
        )
        |> Repo.update_all(set: [has_voted: true])
    end
  end

  # ==================== Budget Management ====================

  def list_budget_items(trip_id) do
    query =
      from(b in BudgetItem,
        where: b.trip_id == ^trip_id,
        order_by: [desc: b.expense_date],
        preload: [:paid_by]
      )

    Repo.all(query)
  end

  def create_budget_item(attrs) do
    %BudgetItem{}
    |> BudgetItem.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, item} ->
        update_trip_budget(item.trip_id)
        {:ok, item}

      error ->
        error
    end
  end

  def update_budget_item(%BudgetItem{} = item, attrs) do
    item
    |> BudgetItem.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        update_trip_budget(updated.trip_id)
        {:ok, updated}

      error ->
        error
    end
  end

  def delete_budget_item(%BudgetItem{} = item) do
    trip_id = item.trip_id
    Repo.delete(item)
    update_trip_budget(trip_id)
  end

  defp update_trip_budget(trip_id) do
    query = from(b in BudgetItem, where: b.trip_id == ^trip_id, select: sum(b.amount))
    total_committed = Repo.aggregate(query, :sum) || 0

    from(t in Trip, where: t.id == ^trip_id)
    |> Repo.update_all(set: [total_budget_committed: total_committed])
  end

  def get_budget_summary(trip_id) do
    items = list_budget_items(trip_id)
    participants = get_trip_participants(trip_id)
    total = Enum.sum(Enum.map(items, & &1.amount))
    per_person = if length(participants) > 0, do: div(total, length(participants)), else: 0

    categories = %{
      "accommodation" =>
        Enum.filter(items, &(&1.category == "accommodation"))
        |> Enum.map(& &1.amount)
        |> Enum.sum(),
      "activities" =>
        Enum.filter(items, &(&1.category == "activities")) |> Enum.map(& &1.amount) |> Enum.sum(),
      "food" =>
        Enum.filter(items, &(&1.category == "food")) |> Enum.map(& &1.amount) |> Enum.sum(),
      "transport" =>
        Enum.filter(items, &(&1.category == "transport")) |> Enum.map(& &1.amount) |> Enum.sum(),
      "other" =>
        Enum.filter(items, &(&1.category == "other")) |> Enum.map(& &1.amount) |> Enum.sum()
    }

    %{
      total: total,
      per_person: per_person,
      categories: categories,
      items: items,
      participant_count: length(participants)
    }
  end

  # ==================== Packing Lists ====================

  def list_packing_items(trip_id) do
    query =
      from(p in PackingItem,
        where: p.trip_id == ^trip_id,
        order_by: [asc: p.order_index, asc: p.category]
      )

    Repo.all(query)
  end

  def create_packing_item(attrs) do
    %PackingItem{}
    |> PackingItem.changeset(attrs)
    |> Repo.insert()
  end

  def toggle_packing_item(item_id) do
    case Repo.get(PackingItem, item_id) do
      nil ->
        {:error, :not_found}

      item ->
        item
        |> PackingItem.changeset(%{is_checked: !item.is_checked})
        |> Repo.update()
    end
  end

  def delete_packing_item(%PackingItem{} = item) do
    Repo.delete(item)
  end

  def generate_ai_packing_list(trip_id) do
    trip = get_trip!(trip_id)

    # Basic rule-based packing suggestions based on destination and duration
    suggestions = [
      %{name: "Passport/ID", category: "documents"},
      %{name: "Travel insurance", category: "documents"},
      %{name: "Phone and charger", category: "electronics"},
      %{name: "Power bank", category: "electronics"},
      %{name: "Comfortable walking shoes", category: "clothing"},
      %{name: "Weather-appropriate clothing", category: "clothing"},
      %{name: "Toiletries", category: "health"},
      %{name: "Medications", category: "health"},
      %{name: "First aid kit", category: "health"},
      %{name: "Camera", category: "electronics"},
      %{name: "Reusable water bottle", category: "gear"},
      %{name: "Snacks", category: "general"}
    ]

    # Add destination-specific items
    suggestions =
      if String.contains?(trip.destination, "beach") or
           String.contains?(trip.destination, "coast") do
        suggestions ++
          [
            %{name: "Swimsuit", category: "clothing"},
            %{name: "Sunscreen SPF 50+", category: "health"},
            %{name: "Beach towel", category: "gear"},
            %{name: "Flip flops", category: "clothing"}
          ]
      else
        suggestions
      end

    suggestions =
      if String.contains?(trip.destination, "safari") or
           String.contains?(trip.destination, "Mara") do
        suggestions ++
          [
            %{name: "Binoculars", category: "gear"},
            %{name: "Neutral colored clothing", category: "clothing"},
            %{name: "Insect repellent", category: "health"},
            %{name: "Hat and sunglasses", category: "clothing"}
          ]
      else
        suggestions
      end

    suggestions =
      if String.contains?(trip.destination, "mountain") or
           String.contains?(trip.destination, "hike") or
           String.contains?(trip.destination, "hill") do
        suggestions ++
          [
            %{name: "Hiking boots", category: "clothing"},
            %{name: "Backpack", category: "gear"},
            %{name: "Rain jacket", category: "clothing"},
            %{name: "Warm layers", category: "clothing"}
          ]
      else
        suggestions
      end

    # Add items based on trip duration
    days = Date.diff(trip.end_date, trip.start_date)

    suggestions =
      if days > 3 do
        suggestions ++
          [
            %{name: "Laundry kit", category: "general"},
            %{name: "Extra clothing changes", category: "clothing"}
          ]
      else
        suggestions
      end

    # Create packing items (avoid duplicates)
    existing_names = list_packing_items(trip_id) |> Enum.map(& &1.name)

    suggestions
    |> Enum.filter(fn s -> s.name not in existing_names end)
    |> Enum.each(fn suggestion ->
      create_packing_item(%{
        trip_id: trip_id,
        name: suggestion.name,
        category: suggestion.category,
        is_ai_suggested: true
      })
    end)

    list_packing_items(trip_id)
  end

  # ==================== Vibe Board ====================

  def list_vibe_pins(trip_id) do
    query =
      from(v in VibePin,
        where: v.trip_id == ^trip_id,
        order_by: [desc: v.inserted_at],
        preload: [:user]
      )

    Repo.all(query)
  end

  def create_vibe_pin(attrs) do
    %VibePin{}
    |> VibePin.changeset(attrs)
    |> Repo.insert()
  end

  def delete_vibe_pin(%VibePin{} = pin) do
    Repo.delete(pin)
  end

  # ==================== Trip Chat Integration ====================

  defp create_trip_chat(_trip) do
    # Create a group conversation for the trip
    # This is a placeholder - implement based on your chat system
    {:ok}
  end

  defp add_to_trip_chat(_trip, _user_id) do
    # Add user to trip conversation
    # This is a placeholder - implement based on your chat system
    {:ok}
  end

  defp remove_from_trip_chat(_trip, _user_id) do
    # Remove user from trip conversation
    # This is a placeholder - implement based on your chat system
    {:ok}
  end

  # ==================== Helper Functions ====================

  defp enrich_trip(trip) do
    participants = trip.participants || []
    _member_count = length(participants)

    _online_count =
      Enum.count(participants, fn p ->
        p.user && p.user.last_active &&
          DateTime.diff(DateTime.utc_now(), p.user.last_active, :minute) < 5
      end)

    # Calculate progress from itinerary items
    total_items = length(trip.itinerary_items || [])
    confirmed_items = Enum.count(trip.itinerary_items || [], &(&1.status == "confirmed"))
    progress = if total_items > 0, do: round(confirmed_items / total_items * 100), else: 0

    %{trip | progress_percentage: progress}
  end

  # ==================== Discovery Features ====================

  def get_popular_destinations(limit \\ 10) do
    query =
      from(p in Place,
        where: p.verified == true,
        order_by: [desc: p.safety_score],
        limit: ^limit
      )

    Repo.all(query)
  end

  def get_recommended_guides(limit \\ 10, vibe_tags \\ []) do
    query =
      from(g in Mtaani.Accounts.Guide,
        join: u in assoc(g, :user),
        where: g.verification_status == "verified",
        where: g.availability_status == "online",
        order_by: [desc: g.rating],
        limit: ^limit,
        preload: [:user]
      )

    guides = Repo.all(query)

    # Filter by vibe tags if provided
    if Enum.empty?(vibe_tags) do
      guides
    else
      Enum.filter(guides, fn guide ->
        Enum.any?(vibe_tags, fn tag ->
          tag in (guide.user.travel_vibes || [])
        end)
      end)
    end
  end

  def search_activities(query_term, limit \\ 20) do
    search = "%#{query_term}%"

    from(p in Place,
      where: p.category == "activity",
      where: ilike(p.name, ^search) or ilike(p.description, ^search),
      limit: ^limit,
      order_by: [desc: p.safety_score]
    )
    |> Repo.all()
  end

  def get_transport_options(_from_location, _to_location, _date) do
    # Query transport providers from your transport_providers table
    query =
      from(tp in Mtaani.Transport.TransportProvider,
        where: tp.verified == true,
        limit: 10
      )

    Repo.all(query)
  end
end
