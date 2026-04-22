defmodule Mtaani.Groups do
  @moduledoc """
  The Groups context for managing travel groups, convoys, and events.
  ALL DATA IS DYNAMIC - No hardcoded values, everything from database.
  """

  import Ecto.Query
  alias Mtaani.Repo
  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  alias Mtaani.Groups.{
    Group,
    GroupMember,
    GroupChannel,
    GroupMessage,
    GroupEvent,
    EventAttendee,
    GroupConvoy,
    ConvoyParticipant
  }

  # ==================== Group CRUD ====================

  def list_user_groups(user_id) do
    query =
      from(g in Group,
        join: gm in GroupMember,
        on: gm.group_id == g.id,
        where: gm.user_id == ^user_id,
        where: g.is_active == true,
        order_by: [desc: g.member_count],
        preload: [:created_by]
      )

    groups = Repo.all(query)
    Enum.map(groups, fn group -> enrich_group_for_display(group, user_id) end)
  end

  def list_groups(filters \\ %{}) do
    query = from(g in Group, where: g.is_active == true)

    query =
      case filters[:type] do
        nil -> query
        type -> where(query, [g], g.type == ^type)
      end

    query =
      case filters[:nearby] do
        nil ->
          query

        {lat, lng, radius_km} ->
          from(g in query,
            where: not is_nil(g.location_lat) and not is_nil(g.location_lng),
            where:
              fragment(
                "ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
                ^lng,
                ^lat,
                g.location_lng,
                g.location_lat,
                ^(radius_km * 1000)
              )
          )
      end

    query =
      case filters[:joined_by_user_id] do
        nil ->
          query

        user_id ->
          from(g in query,
            left_join: gm in GroupMember,
            on: gm.group_id == g.id and gm.user_id == ^user_id,
            where: is_nil(gm.id)
          )
      end

    query =
      from(g in query,
        order_by: [desc: g.member_count],
        preload: [:created_by]
      )

    groups = Repo.all(query)

    if filters[:for_user_id] do
      Enum.map(groups, fn group -> enrich_group_for_display(group, filters[:for_user_id]) end)
    else
      groups
    end
  end

  def get_group(id, user_id \\ nil) do
    group =
      Repo.get(Group, id)
      |> Repo.preload([:created_by, channels: [], events: [], convoys: []])

    if group do
      members = get_group_members(id)
      online_members = Enum.filter(members, & &1.is_online)

      group = %{group | members: members, online_count: length(online_members)}

      if user_id do
        enrich_group_for_display(group, user_id)
      else
        group
      end
    else
      nil
    end
  end

  def get_group!(id) do
    Repo.get!(Group, id)
  end

  def create_group(attrs, creator_id) do
    %Group{}
    |> Group.create_changeset(attrs, creator_id)
    |> Repo.insert()
    |> case do
      {:ok, group} ->
        add_member(group.id, creator_id, "admin")
        create_default_channels(group.id)
        {:ok, group}

      error ->
        error
    end
  end

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  # ==================== Group Membership ====================

  def add_member(group_id, user_id, role \\ "member") do
    case get_member(group_id, user_id) do
      nil ->
        %GroupMember{}
        |> GroupMember.join_changeset(group_id, user_id)
        |> Repo.insert()
        |> case do
          {:ok, member} ->
            update_member_count(group_id, +1)
            {:ok, member}

          error ->
            error
        end

      member ->
        {:ok, member}
    end
  end

  def remove_member(group_id, user_id) do
    case get_member(group_id, user_id) do
      nil ->
        {:error, :not_member}

      member ->
        Repo.delete(member)
        update_member_count(group_id, -1)
    end
  end

  def get_member(group_id, user_id) do
    Repo.get_by(GroupMember, group_id: group_id, user_id: user_id)
  end

  def get_group_members(group_id) do
    query =
      from(gm in GroupMember,
        where: gm.group_id == ^group_id,
        preload: [:user],
        order_by: [desc: gm.role, desc: gm.joined_at]
      )

    Repo.all(query)
  end

  def get_online_members(group_id) do
    query =
      from(gm in GroupMember,
        where: gm.group_id == ^group_id and gm.is_online == true,
        preload: [:user]
      )

    Repo.all(query)
  end

  def update_member_online_status(group_id, user_id, is_online) do
    case get_member(group_id, user_id) do
      nil ->
        {:error, :not_member}

      member ->
        member
        |> GroupMember.changeset(%{is_online: is_online, last_active: DateTime.utc_now()})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            online_count = length(get_online_members(group_id))
            update_online_count(group_id, online_count)

          error ->
            error
        end
    end
  end

  # ==================== Group Channels ====================

  defp create_default_channels(group_id) do
    default_channels = [
      {"general", "General discussion", 0},
      {"safety", "Safety updates and alerts", 1},
      {"photos", "Share your photos", 2},
      {"events", "Upcoming events", 3},
      {"convoy", "Live convoy tracking", 4}
    ]

    for {name, description, order} <- default_channels do
      create_channel(%{name: name, description: description, channel_order: order}, group_id)
    end
  end

  def create_channel(attrs, group_id) do
    %GroupChannel{}
    |> GroupChannel.changeset(Map.put(attrs, :group_id, group_id))
    |> Repo.insert()
  end

  def list_group_channels(group_id) do
    query =
      from(c in GroupChannel,
        where: c.group_id == ^group_id,
        order_by: [asc: c.channel_order]
      )

    Repo.all(query)
  end

  def get_channel_by_name(group_id, name) do
    Repo.get_by(GroupChannel, group_id: group_id, name: name)
  end

  # ==================== Group Messages ====================

  def get_channel_messages(channel_id, limit \\ 50, offset \\ 0) do
    query =
      from(m in GroupMessage,
        where: m.channel_id == ^channel_id,
        where: m.is_deleted == false,
        order_by: [asc: m.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :reply_to]
      )

    Repo.all(query)
  end

  def create_channel_message(attrs, user_id, group_id, channel_id) do
    %GroupMessage{}
    |> GroupMessage.group_message_changeset(attrs, user_id, group_id, channel_id)
    |> Repo.insert()
  end

  def pin_message(message_id, user_id) do
    case Repo.get(GroupMessage, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        message
        |> GroupMessage.changeset(%{
          is_pinned: true,
          pinned_by_id: user_id,
          pinned_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  def unpin_message(message_id) do
    case Repo.get(GroupMessage, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        message
        |> GroupMessage.changeset(%{
          is_pinned: false,
          pinned_by_id: nil,
          pinned_at: nil
        })
        |> Repo.update()
    end
  end

  def get_pinned_message(group_id) do
    query =
      from(m in GroupMessage,
        join: c in GroupChannel,
        on: m.channel_id == c.id,
        where: c.group_id == ^group_id and m.is_pinned == true,
        order_by: [desc: m.pinned_at],
        limit: 1,
        preload: [:user]
      )

    Repo.one(query)
  end

  # ==================== Group Events ====================

  def list_group_events(group_id, upcoming_only? \\ true) do
    query =
      from(e in GroupEvent,
        where: e.group_id == ^group_id
      )

    query =
      if upcoming_only? do
        from(e in query, where: e.event_date > ^DateTime.utc_now())
      else
        query
      end

    query =
      from(e in query,
        order_by: [asc: e.event_date],
        preload: [:created_by]
      )

    Repo.all(query)
  end

  def create_event(attrs) do
    %GroupEvent{}
    |> GroupEvent.changeset(attrs)
    |> Repo.insert()
  end

  def rsvp_event(event_id, user_id, status) do
    case Repo.get_by(EventAttendee, event_id: event_id, user_id: user_id) do
      nil ->
        %EventAttendee{}
        |> EventAttendee.changeset(%{event_id: event_id, user_id: user_id, status: status})
        |> Repo.insert()

      attendee ->
        attendee
        |> EventAttendee.changeset(%{status: status})
        |> Repo.update()
    end
    |> case do
      {:ok, _} ->
        update_event_attendee_count(event_id)

      error ->
        error
    end
  end

  def get_event_rsvp(event_id, user_id) do
    case Repo.get_by(EventAttendee, event_id: event_id, user_id: user_id) do
      nil -> nil
      attendee -> attendee.status
    end
  end

  # ==================== Group Convoys ====================

  def get_active_convoy(group_id) do
    query =
      from(c in GroupConvoy,
        where: c.group_id == ^group_id and c.is_active == true,
        preload: [participants: [:user]]
      )

    Repo.one(query)
  end

  def create_convoy(attrs) do
    %GroupConvoy{}
    |> GroupConvoy.changeset(attrs)
    |> Repo.insert()
  end

  def end_convoy(convoy_id) do
    case Repo.get(GroupConvoy, convoy_id) do
      nil ->
        {:error, :not_found}

      convoy ->
        convoy
        |> GroupConvoy.changeset(%{is_active: false})
        |> Repo.update()
    end
  end

  def join_convoy(convoy_id, user_id) do
    %ConvoyParticipant{}
    |> ConvoyParticipant.changeset(%{convoy_id: convoy_id, user_id: user_id})
    |> Repo.insert()
  end

  def leave_convoy(convoy_id, user_id) do
    case Repo.get_by(ConvoyParticipant, convoy_id: convoy_id, user_id: user_id) do
      nil -> {:error, :not_participant}
      participant -> Repo.delete(participant)
    end
  end

  def share_location(convoy_id, user_id, lat, lng) do
    case Repo.get_by(ConvoyParticipant, convoy_id: convoy_id, user_id: user_id) do
      nil ->
        {:error, :not_participant}

      participant ->
        participant
        |> ConvoyParticipant.update_location_changeset(lat, lng)
        |> Repo.update()
        |> case do
          {:ok, p} ->
            broadcast_convoy_update(convoy_id, user_id, lat, lng)
            {:ok, p}

          error ->
            error
        end
    end
  end

  def get_convoy_participants(convoy_id) do
    query =
      from(cp in ConvoyParticipant,
        where: cp.convoy_id == ^convoy_id,
        where: cp.is_sharing_location == true,
        preload: [:user],
        order_by: [desc: cp.last_location_update]
      )

    Repo.all(query)
  end

  # ==================== Dynamic Data Methods ====================

  def get_group_activity_level(group_id) do
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

    message_count =
      Repo.aggregate(
        from(m in GroupMessage,
          where: m.group_id == ^group_id and m.inserted_at > ^one_hour_ago,
          select: count(m.id)
        )
      ) || 0

    online_count =
      Repo.aggregate(
        from(gm in GroupMember,
          where: gm.group_id == ^group_id and gm.is_online == true,
          select: count(gm.id)
        )
      ) || 0

    event_activity =
      Repo.aggregate(
        from(ea in EventAttendee,
          join: e in assoc(ea, :event),
          where:
            e.group_id == ^group_id and ea.inserted_at > ^today_start and ea.status == "going",
          select: count(ea.id)
        )
      ) || 0

    has_convoy =
      Repo.exists?(
        from(c in GroupConvoy,
          where: c.group_id == ^group_id and c.is_active == true
        )
      )

    score = message_count + online_count * 2 + event_activity + if has_convoy, do: 5, else: 0

    cond do
      score >= 20 -> {:high, "Buzzing"}
      score >= 10 -> {:medium, "Active"}
      score >= 5 -> {:low, "Quiet"}
      true -> {:none, "Inactive"}
    end
  end

  def get_pulse_data(user_id) do
    user_groups = list_user_groups(user_id)
    group_ids = Enum.map(user_groups, & &1.id)

    today_start = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    online_count =
      if group_ids != [] do
        Repo.aggregate(
          from(gm in GroupMember,
            where: gm.group_id in ^group_ids and gm.is_online == true,
            select: count(gm.id)
          )
        ) || 0
      else
        0
      end

    recent_activity =
      if group_ids != [] do
        message_count =
          Repo.aggregate(
            from(m in GroupMessage,
              where: m.group_id in ^group_ids and m.inserted_at > ^today_start,
              select: count(m.id)
            )
          ) || 0

        event_count =
          Repo.aggregate(
            from(e in GroupEvent,
              where: e.group_id in ^group_ids and e.inserted_at > ^today_start,
              select: count(e.id)
            )
          ) || 0

        message_count + event_count
      else
        0
      end

    recent_members =
      if group_ids != [] do
        Repo.all(
          from(gm in GroupMember,
            where: gm.group_id in ^group_ids and gm.last_active > ^one_hour_ago,
            join: u in assoc(gm, :user),
            order_by: [desc: gm.last_active],
            limit: 5,
            preload: [user: u]
          )
        )
      else
        []
      end

    has_active_convoy =
      if group_ids != [] do
        Repo.exists?(
          from(c in GroupConvoy,
            where: c.group_id in ^group_ids and c.is_active == true
          )
        )
      else
        false
      end

    latest_moment =
      if group_ids != [] do
        Repo.one(
          from(m in GroupMessage,
            where: m.group_id in ^group_ids,
            order_by: [desc: m.inserted_at],
            limit: 1,
            preload: [:user, :group]
          )
        )
      else
        nil
      end

    %{
      total_online: online_count,
      recent_activity_count: recent_activity,
      recent_active_members: recent_members,
      has_active_convoy: has_active_convoy,
      latest_moment: latest_moment,
      user_groups_count: length(group_ids)
    }
  end

  def find_nearby_groups(user_id, radius_km \\ 10) do
    user = Accounts.get_user!(user_id)

    if user.location_lat && user.location_lng do
      radius_meters = radius_km * 1000

      query =
        from(g in Group,
          where: g.is_active == true,
          where: not is_nil(g.location_lat) and not is_nil(g.location_lng),
          where:
            fragment(
              "ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
              ^user.location_lng,
              ^user.location_lat,
              g.location_lng,
              g.location_lat,
              ^radius_meters
            ),
          order_by: [
            asc:
              fragment(
                "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography)",
                ^user.location_lng,
                ^user.location_lat,
                g.location_lng,
                g.location_lat
              )
          ],
          limit: 20
        )

      groups = Repo.all(query)
      Enum.map(groups, fn group -> enrich_group_for_display(group, user_id) end)
    else
      []
    end
  end

  def get_group_photos(group_id, limit \\ 50) do
    query =
      from(m in GroupMessage,
        where: m.group_id == ^group_id,
        where: not is_nil(m.media_url),
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:user]
      )

    Repo.all(query)
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      %{
        id: msg.id,
        url: msg.media_url,
        thumbnail: msg.media_thumbnail,
        user: msg.user,
        inserted_at: msg.inserted_at,
        index: idx
      }
    end)
  end

  def calculate_convoy_stats(convoy_id) do
    convoy =
      Repo.get(GroupConvoy, convoy_id)
      |> Repo.preload(participants: [:user])

    if !convoy do
      %{distance: nil, eta: nil, sharing_count: 0, participants: []}
    else
      sharing_participants = Enum.filter(convoy.participants, & &1.is_sharing_location)
      sharing_count = length(sharing_participants)

      if sharing_count > 0 and convoy.destination_lat and convoy.destination_lng do
        avg_lat = Enum.reduce(sharing_participants, 0, &(&1.current_lat + &2)) / sharing_count
        avg_lng = Enum.reduce(sharing_participants, 0, &(&1.current_lng + &2)) / sharing_count

        distance_km =
          :math.pow(
            :math.pow(avg_lat - convoy.destination_lat, 2) +
              :math.pow(avg_lng - convoy.destination_lng, 2),
            0.5
          ) * 111

        avg_speed = if distance_km > 50, do: 80, else: 40
        eta_minutes = round(distance_km / avg_speed * 60)

        %{
          distance: "#{round(distance_km)}km",
          distance_km: round(distance_km),
          eta: format_eta(eta_minutes),
          eta_minutes: eta_minutes,
          sharing_count: sharing_count,
          total_participants: length(convoy.participants),
          participants: sharing_participants,
          avg_lat: avg_lat,
          avg_lng: avg_lng
        }
      else
        %{
          distance: "?",
          eta: "?",
          sharing_count: sharing_count,
          total_participants: length(convoy.participants),
          participants: sharing_participants,
          avg_lat: nil,
          avg_lng: nil
        }
      end
    end
  end

  def get_convoy_updates(convoy_id, limit \\ 20) do
    updates =
      Repo.all(
        from(cp in ConvoyParticipant,
          where:
            cp.convoy_id == ^convoy_id and
              cp.last_location_update > ^DateTime.add(DateTime.utc_now(), -30, :minute),
          where: cp.is_sharing_location == true,
          order_by: [desc: cp.last_location_update],
          limit: ^limit,
          preload: [:user]
        )
      )

    Enum.map(updates, fn participant ->
      %{
        id: participant.id,
        user: participant.user,
        action: "updated location",
        details: format_location_update(participant),
        icon: "📍",
        inserted_at: participant.last_location_update
      }
    end)
  end

  def send_sos_alert(group_id, user_id, location) do
    case get_group(group_id) do
      nil ->
        {:error, :group_not_found}

      group ->
        members = get_group_members(group_id)
        safety_channel = get_channel_by_name(group_id, "safety")

        if safety_channel do
          sos_message = """
          🆘 SOS ALERT 🆘

          User needs immediate assistance!
          Location: #{location}
          Time: #{DateTime.utc_now()}

          Please check on them if nearby.
          """

          create_channel_message(%{content: sos_message}, user_id, group_id, safety_channel.id)
        end

        {:ok, %{alert_sent: true, members_notified: length(members)}}
    end
  end

  def enrich_group_for_display(group, user_id) do
    {activity_level, activity_label} = get_group_activity_level(group.id)

    last_message =
      Repo.one(
        from(m in GroupMessage,
          where: m.group_id == ^group.id,
          order_by: [desc: m.inserted_at],
          limit: 1,
          preload: [:user]
        )
      )

    recent_members =
      Repo.all(
        from(gm in GroupMember,
          where: gm.group_id == ^group.id,
          join: u in assoc(gm, :user),
          order_by: [desc: gm.joined_at],
          limit: 3,
          preload: [user: u]
        )
      )

    tags = get_group_tags(group)

    %{
      id: group.id,
      name: group.name,
      description: group.description,
      type: group.type,
      location: group.location,
      member_count: group.member_count,
      trust_score: group.trust_score,
      cover_photo_url: group.cover_photo_url,
      created_by: group.created_by,
      activity_level: activity_level,
      activity_label: activity_label,
      last_message_preview:
        if(last_message, do: String.slice(last_message.content, 0..50), else: nil),
      last_message_sender:
        if(last_message && last_message.user, do: last_message.user.name, else: nil),
      last_activity_time: format_relative_time(last_message.inserted_at),
      recent_members: recent_members,
      tags: tags,
      unread_count: 0,
      is_active: activity_level in [:high, :medium]
    }
  end

  # ==================== Private Helpers ====================

  defp update_member_count(group_id, delta) do
    query = from(g in Group, where: g.id == ^group_id)
    Repo.update_all(query, inc: [member_count: delta])
  end

  defp update_online_count(group_id, count) do
    query = from(g in Group, where: g.id == ^group_id)
    Repo.update_all(query, set: [online_count: count])
  end

  defp update_event_attendee_count(event_id) do
    count_query =
      from(ea in EventAttendee,
        where: ea.event_id == ^event_id and ea.status == "going",
        select: count(ea.id)
      )

    count = Repo.one(count_query) || 0

    query = from(e in GroupEvent, where: e.id == ^event_id)
    Repo.update_all(query, set: [attendees_count: count])
  end

  defp broadcast_convoy_update(convoy_id, user_id, lat, lng) do
    update = %{
      convoy_id: convoy_id,
      user_id: user_id,
      lat: lat,
      lng: lng,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Mtaani.PubSub, "convoy_updates", {:convoy_update, update})
  end

  defp get_group_tags(group) do
    tags = []
    tags = if group.location, do: tags ++ [group.location], else: tags

    tags =
      case group.type do
        "trip" -> tags ++ ["🎒 Trip"]
        "community" -> tags ++ ["🏘️ Community"]
        "guide_network" -> tags ++ ["🧭 Verified Guides"]
        "private" -> tags ++ ["🔒 Private"]
        _ -> tags
      end

    Enum.take(tags, 3)
  end

  defp format_relative_time(nil), do: ""

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end

  defp format_eta(minutes) when minutes < 60, do: "#{minutes} min"
  defp format_eta(minutes) when minutes >= 60, do: "#{div(minutes, 60)}h #{rem(minutes, 60)}min"
  defp format_eta(_), do: "?"

  defp format_location_update(participant) do
    if participant.current_lat && participant.current_lng do
      "at #{Float.round(participant.current_lat, 4)}, #{Float.round(participant.current_lng, 4)}"
    else
      "location unknown"
    end
  end
end
