defmodule Mtaani.Accounts do
  @moduledoc """
  The Accounts context for user management and authentication.
  """

  alias Mtaani.Repo
  alias Mtaani.Accounts.User
  alias Mtaani.Social.Connection
  alias Mtaani.Social.UserPhoto
  alias Mtaani.Social.UserAlbum
  alias Mtaani.Accounts.Guide
  alias Mtaani.Accounts.UserVisit
  alias Mtaani.Accounts.UserBadge
  alias Mtaani.Accounts.Badge
  alias Mtaani.Social.Post

  import Ecto.Query
  import Ecto.Changeset

  # ============ PHONE FORMATTING ============

  defp format_phone(nil), do: nil

  defp format_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    cond do
      String.starts_with?(digits, "254") and String.length(digits) == 12 ->
        "+" <> digits

      String.starts_with?(digits, "07") and String.length(digits) == 10 ->
        "+254" <> String.slice(digits, 1, 9)

      String.starts_with?(digits, "7") and String.length(digits) == 9 ->
        "+254" <> digits

      true ->
        nil
    end
  end

  defp format_phone(_), do: nil

  # ============ USER LOOKUP ============

  @doc "Get a user by phone number."
  def get_user_by_phone(phone) do
    if is_nil(phone) do
      nil
    else
      formatted = format_phone(phone)
      if formatted, do: Repo.get_by(User, phone: formatted), else: nil
    end
  end

  @doc "Get a user by ID."
  def get_user(id), do: Repo.get(User, id)

  @doc "Get a user by username."
  def get_user_by_username(username), do: Repo.get_by(User, username: username)

  # ============ GUIDE MANAGEMENT ============

  @doc "Get nearby guides based on user location."
  def get_nearby_guides(lat, lng, radius_km \\ 10) do
    query =
      from(u in User,
        join: g in Guide,
        on: u.id == g.user_id,
        where: u.is_guide == true,
        where: g.availability_status == "online",
        where: g.verification_status == "verified",
        where: not is_nil(u.location_lat) and not is_nil(u.location_lng),
        where:
          fragment(
            "earth_distance(ll_to_earth(?, ?), ll_to_earth(?, ?)) <= ?",
            u.location_lat,
            u.location_lng,
            ^lat,
            ^lng,
            ^(radius_km * 1000)
          ),
        order_by: [
          asc:
            fragment(
              "earth_distance(ll_to_earth(?, ?), ll_to_earth(?, ?))",
              u.location_lat,
              u.location_lng,
              ^lat,
              ^lng
            )
        ],
        limit: 10,
        preload: [guide: :user]
      )

    Repo.all(query)
  end

  @doc "Get count of nearby guides."
  def get_nearby_guides_count(lat, lng, radius_km \\ 10) do
    query =
      from(u in User,
        join: g in Guide,
        on: u.id == g.user_id,
        where: u.is_guide == true,
        where: g.availability_status == "online",
        where: g.verification_status == "verified",
        where: not is_nil(u.location_lat) and not is_nil(u.location_lng),
        where:
          fragment(
            "earth_distance(ll_to_earth(?, ?), ll_to_earth(?, ?)) <= ?",
            u.location_lat,
            u.location_lng,
            ^lat,
            ^lng,
            ^(radius_km * 1000)
          )
      )

    Repo.aggregate(query, :count, :id)
  end

  @doc "Create or update a guide profile."
  def upsert_guide(user_id, attrs) do
    case Repo.get_by(Guide, user_id: user_id) do
      nil ->
        %Guide{user_id: user_id}
        |> Guide.changeset(attrs)
        |> Repo.insert()

      guide ->
        guide
        |> Guide.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc "Get guide by user ID."
  def get_guide_by_user_id(user_id), do: Repo.get_by(Guide, user_id: user_id)

  @doc "Update user profile with complete profile fields (for profile setup)."
  def update_complete_profile(user, attrs) do
    user
    |> User.complete_profile_changeset(attrs)
    |> Repo.update()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :bio,
      :location,
      :website,
      :is_private,
      :cover_photo_url,
      :profile_photo_url,
      :traveler_type,
      :travel_vibes
    ])
    |> validate_length(:bio, max: 160)
  end

  # ============ AUTHENTICATION ============

  @doc "Authenticate a user by phone and password."
  def authenticate_user(phone, password) do
    user = get_user_by_phone(phone)

    cond do
      is_nil(user) -> {:error, "Invalid phone number or password"}
      Pbkdf2.verify_pass(password, user.password_hash) -> {:ok, user}
      true -> {:error, "Invalid phone number or password"}
    end
  end

  # ============ USER CREATION ============

  @doc "Create a new user with phone verification."
  def create_user(attrs) do
    attrs = for {key, val} <- attrs, into: %{}, do: {to_string(key), val}
    raw_phone = attrs["phone"]
    phone = format_phone(raw_phone)

    if is_nil(phone) do
      {:error, "Phone number is required. Please use format: 07XXXXXXXX"}
    else
      attrs = Map.put(attrs, "phone", phone)

      %User{}
      |> User.registration_changeset(attrs)
      |> Repo.insert()
    end
  end

  # ============ PROFILE MANAGEMENT ============

  @doc "Update user photo (profile or cover)."
  def update_user_photo(user, photo_url, type), do: User.update_photo(user, photo_url, type)

  # ============ VERIFICATION ============

  @doc "Generate a 6-digit verification code."
  def generate_verification_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc "Send verification code via SMS."
  def send_verification_code(phone, code) do
    IO.puts("SMS to #{phone}: Your Mtaani verification code is: #{code}")
    {:ok, "sent"}
  end

  @doc "Verify a user's phone with the provided code."
  def verify_phone(user, code) do
    if user.verification_code == code do
      user
      |> User.verification_changeset(%{phone_verified: true, verification_code: nil})
      |> Repo.update()
    else
      {:error, "Invalid verification code"}
    end
  end

  # ============ TRAVEL BUDDIES ============

  @doc "Get user's travel buddies (accepted connections)."
  def get_travel_buddies(user) do
    query =
      from(c in Connection,
        where: (c.user_id == ^user.id or c.buddy_id == ^user.id) and c.status == "accepted",
        preload: [:user, :buddy]
      )

    Repo.all(query)
    |> Enum.map(fn connection ->
      if connection.user_id == user.id, do: connection.buddy, else: connection.user
    end)
  end

  @doc "Send a connection request to another user."
  def send_connection_request(user_id, buddy_id) do
    %Connection{}
    |> Connection.changeset(%{user_id: user_id, buddy_id: buddy_id, status: "pending"})
    |> Repo.insert()
  end

  @doc "Accept a connection request."
  def accept_connection_request(request_id) do
    connection = Repo.get(Connection, request_id)
    connection |> Connection.changeset(%{status: "accepted"}) |> Repo.update()
  end

  @doc "Decline a connection request."
  def decline_connection_request(request_id) do
    connection = Repo.get(Connection, request_id)
    connection |> Connection.changeset(%{status: "declined"}) |> Repo.update()
  end

  @doc "Get pending connection requests for a user."
  def get_pending_requests(user) do
    query =
      from(c in Connection,
        where: c.buddy_id == ^user.id and c.status == "pending",
        preload: [:user]
      )

    Repo.all(query)
  end

  # ============ PHOTO MANAGEMENT ============

  @doc "Get user's photos."
  def get_user_photos(user) do
    query = from(p in UserPhoto, where: p.user_id == ^user.id, order_by: [desc: p.inserted_at])
    Repo.all(query)
  end

  @doc "Create user album."
  def create_album(user, attrs) do
    %UserAlbum{}
    |> UserAlbum.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc "Add photo to album."
  def add_photo(user, attrs, album_id \\ nil) do
    attrs = Map.put(attrs, :user_id, user.id)
    attrs = if album_id, do: Map.put(attrs, :album_id, album_id), else: attrs

    %UserPhoto{}
    |> UserPhoto.changeset(attrs)
    |> Repo.insert()
  end

  # ============ PROFILE STATS ============

  @doc "Get comprehensive user stats for profile display."
  def get_user_stats(user) do
    trips_count = get_trips_count(user.id)
    counties_count = get_counties_visited_count(user.id)

    buddies_query =
      from(c in Connection,
        where: (c.user_id == ^user.id or c.buddy_id == ^user.id) and c.status == "accepted"
      )

    buddies_count = Repo.aggregate(buddies_query, :count, :id)
    posts_count = get_posts_count(user.id)

    %{
      trips_count: trips_count,
      counties_count: counties_count,
      buddies_count: buddies_count,
      followers_count: user.followers_count || 0,
      following_count: user.following_count || 0,
      posts_count: posts_count
    }
  end

  defp get_trips_count(user_id) do
    query = from(v in UserVisit, where: v.user_id == ^user_id, select: count(v.id))
    Repo.one(query) || 0
  end

  defp get_counties_visited_count(user_id) do
    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id and not is_nil(v.county),
        select: fragment("count(DISTINCT ?)", v.county)
      )

    Repo.one(query) || 0
  end

  defp get_posts_count(user_id) do
    query = from(p in Post, where: p.user_id == ^user_id, select: count(p.id))
    Repo.one(query) || 0
  end

  # ============ TRUST SCORE CALCULATION ============

  @doc "Calculate trust score based on earned signals."
  def calculate_trust_score(user) do
    signals = [
      %{key: :phone_verified, points: 20, completed: user.phone_verified == true},
      %{
        key: :profile_complete,
        points: 15,
        completed: profile_complete?(user),
        description: "Photo, bio, location"
      },
      %{
        key: :trips_completed,
        points: 28,
        completed: (get_trips_count(user.id) || 0) > 0,
        description: "#{get_trips_count(user.id)} trips logged"
      },
      %{
        key: :community_active,
        points: 15,
        completed: (get_posts_count(user.id) || 0) > 5,
        description: "Active in community"
      },
      %{
        key: :trips_led,
        points: 10,
        completed: (user.tours_led || 0) > 0,
        description: "Led #{user.tours_led || 0} group trips"
      },
      %{
        key: :id_verified,
        points: 12,
        completed: user.id_verified == true,
        description: "Verify ID to unlock"
      }
    ]

    earned = signals |> Enum.filter(& &1.completed) |> Enum.map(& &1.points) |> Enum.sum()
    total = signals |> Enum.map(& &1.points) |> Enum.sum()
    score = if total > 0, do: round(earned / total * 100), else: 0

    level = get_trust_level(score)
    next_level = get_next_trust_level(score)

    %{
      score: score,
      level: level,
      signals: signals,
      next_level: next_level.name,
      next_threshold: next_level.threshold,
      points_needed: next_level.threshold - score,
      arc_deg: score * 3.6,
      stroke_dashoffset: Float.round(113.1 * (1 - score / 100), 1)
    }
  end

  defp profile_complete?(user) do
    not is_nil(user.profile_photo_url) and
      not is_nil(user.bio) and
      String.trim(user.bio || "") != "" and
      not is_nil(user.location)
  end

  defp get_trust_level(score) do
    cond do
      score >= 95 -> "Community Champion"
      score >= 75 -> "Trusted Traveler"
      score >= 50 -> "Active Member"
      true -> "New Explorer"
    end
  end

  defp get_next_trust_level(score) do
    cond do
      score >= 95 -> %{name: "Community Champion (Max)", threshold: 100}
      score >= 75 -> %{name: "Community Champion", threshold: 95}
      score >= 50 -> %{name: "Trusted Traveler", threshold: 75}
      true -> %{name: "Active Member", threshold: 50}
    end
  end

  # ============ USER VISITS ============

  @doc "Record a user visit to a place."
  def record_user_visit(user_id, attrs) do
    %UserVisit{}
    |> UserVisit.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
    |> case do
      {:ok, visit} ->
        update_user_trip_counts(user_id)
        {:ok, visit}

      error ->
        error
    end
  end

  defp update_user_trip_counts(user_id) do
    trips_count = get_trips_count(user_id)
    counties_count = get_counties_visited_count(user_id)

    Repo.update_all(from(u in User, where: u.id == ^user_id),
      set: [trips_count: trips_count, counties_visited_count: counties_count]
    )
  end

  @doc "Get user's visited places with details."
  def get_visited_places(user_id, limit \\ 10) do
    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id,
        order_by: [desc: v.visited_at],
        limit: ^limit,
        preload: [:place]
      )

    Repo.all(query)
  end

  # ============ POSTS FOR PROFILE ============

  @doc "Get user's posts for profile feed."
  def get_user_posts(user_id, page \\ 1, per_page \\ 20) do
    offset = (page - 1) * per_page

    query =
      from(p in Post,
        where: p.user_id == ^user_id,
        order_by: [desc: p.inserted_at],
        limit: ^per_page,
        offset: ^offset,
        preload: [:user]
      )

    {Repo.all(query), Repo.aggregate(from(p in Post, where: p.user_id == ^user_id), :count, :id)}
  end

  # ============ PHOTOS & ALBUMS ============

  @doc "Get user's photos grouped by album."
  def get_user_photos_with_albums(user_id) do
    albums =
      Repo.all(
        from(a in UserAlbum,
          where: a.user_id == ^user_id,
          order_by: [desc: a.inserted_at],
          preload: [:photos]
        )
      )

    recent_photos =
      Repo.all(
        from(p in UserPhoto,
          where: p.user_id == ^user_id and is_nil(p.album_id),
          order_by: [desc: p.inserted_at],
          limit: 9
        )
      )

    %{albums: albums, recent_photos: recent_photos}
  end

  @doc "Update cover photo."
  def update_cover_photo(user, photo_url) do
    user |> User.changeset(%{cover_photo_url: photo_url}) |> Repo.update()
  end

  @doc "Update profile photo."
  def update_profile_photo(user, photo_url) do
    user |> User.changeset(%{profile_photo_url: photo_url}) |> Repo.update()
  end

  @doc "Update full profile with all editable fields."
  def update_profile(user, attrs) do
    travel_vibes = Map.get(attrs, :travel_vibes)
    attrs = Map.drop(attrs, [:travel_vibes])

    user
    |> User.profile_changeset(attrs)
    |> maybe_update_travel_vibes(travel_vibes)
    |> Repo.update()
  end

  defp maybe_update_travel_vibes(changeset, nil), do: changeset

  defp maybe_update_travel_vibes(changeset, vibes) when is_list(vibes) do
    put_change(changeset, :travel_vibes, vibes)
  end

  # ============ FOLLOW SYSTEM ============

  @doc "Check if a user is following another user."
  def following?(follower_id, following_id) do
    query =
      from(c in Connection,
        where:
          c.user_id == ^following_id and c.buddy_id == ^follower_id and c.status == "accepted"
      )

    Repo.exists?(query)
  end

  @doc "Follow a user."
  def follow_user(follower_id, following_id) do
    case Repo.get_by(Connection, user_id: following_id, buddy_id: follower_id) do
      nil ->
        result =
          %Connection{}
          |> Connection.changeset(%{
            user_id: following_id,
            buddy_id: follower_id,
            status: "accepted"
          })
          |> Repo.insert()

        update_follow_counts(follower_id, following_id, 1)
        result

      connection ->
        result = connection |> Connection.changeset(%{status: "accepted"}) |> Repo.update()
        update_follow_counts(follower_id, following_id, 1)
        result
    end
  end

  @doc "Unfollow a user."
  def unfollow_user(follower_id, following_id) do
    case Repo.get_by(Connection, user_id: following_id, buddy_id: follower_id) do
      nil ->
        {:ok, nil}

      connection ->
        result = Repo.delete(connection)
        update_follow_counts(follower_id, following_id, -1)
        result
    end
  end

  defp update_follow_counts(follower_id, following_id, delta) do
    Repo.update_all(from(u in User, where: u.id == ^follower_id), inc: [following_count: delta])
    Repo.update_all(from(u in User, where: u.id == ^following_id), inc: [followers_count: delta])
  end

  # ============ BUDDIES ============

  @doc "Get connected buddies (accepted connections)."
  def get_connected_buddies(user_id) do
    query =
      from(c in Connection,
        where: (c.user_id == ^user_id or c.buddy_id == ^user_id) and c.status == "accepted",
        preload: [:user, :buddy]
      )

    Repo.all(query)
    |> Enum.map(fn conn -> if conn.user_id == user_id, do: conn.buddy, else: conn.user end)
  end

  @doc "Get suggested buddies (users not yet connected)."
  def get_suggested_buddies(user_id, limit \\ 10) do
    connected_ids = get_connected_buddies(user_id) |> Enum.map(& &1.id)
    excluded_ids = [user_id | connected_ids]

    query =
      from(u in User,
        where: u.id not in ^excluded_ids,
        order_by: [desc: u.inserted_at],
        limit: ^limit
      )

    Repo.all(query)
  end

  # ============ DYNAMIC BADGE SYSTEM ============

  @doc "Get all available badges (for admin/config)"
  def get_all_badges do
    query =
      from(b in Badge,
        where: b.is_active == true,
        order_by: [asc: b.category, asc: b.threshold_value]
      )

    Repo.all(query)
  end

  @doc "Get user's earned badges with badge definitions"
  def get_user_badges(user_id) do
    query =
      from(ub in UserBadge,
        where: ub.user_id == ^user_id,
        join: b in assoc(ub, :badge),
        preload: [:badge],
        order_by: [desc: ub.earned_at]
      )

    Repo.all(query)
  end

  @doc "Get user stats needed for badge calculations"
  def get_user_badge_stats(user_id) do
    user = get_user(user_id)

    trips_count = get_trips_count(user_id)
    counties_count = get_counties_visited_count(user_id)
    posts_count = get_posts_count(user_id)
    photos_count = count_user_photos(user_id)
    tours_led = user.tours_led || 0
    comments_count = count_user_comments(user_id)
    reports_count = count_user_reports(user_id)
    peaks_climbed = count_peaks_visited(user_id)
    coast_visits = count_coast_visits(user_id)
    cultural_sites = count_cultural_sites_visited(user_id)
    sunrise_checkins = count_sunrise_checkins(user_id)

    %{
      user_id: user_id,
      trips_count: trips_count,
      counties_count: counties_count,
      posts_count: posts_count,
      photos_count: photos_count,
      tours_led: tours_led,
      comments_count: comments_count,
      reports_count: reports_count,
      peaks_climbed: peaks_climbed,
      coast_visits: coast_visits,
      cultural_sites: cultural_sites,
      sunrise_checkins: sunrise_checkins
    }
  end

  defp count_user_photos(user_id) do
    query = from(p in UserPhoto, where: p.user_id == ^user_id, select: count(p.id))
    Repo.one(query) || 0
  end

  defp count_user_comments(_user_id) do
    # Placeholder - adjust when Comment schema exists
    0
  end

  defp count_user_reports(_user_id) do
    # Placeholder - adjust when Report schema exists
    0
  end

  defp count_peaks_visited(user_id) do
    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id and v.metadata["peak"] == true,
        select: count(v.id)
      )

    Repo.one(query) || 0
  end

  defp count_coast_visits(user_id) do
    coast_counties = ["Mombasa", "Kwale", "Kilifi", "Lamu", "Tana River"]

    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id and v.county in ^coast_counties,
        select: count(v.id)
      )

    Repo.one(query) || 0
  end

  defp count_cultural_sites_visited(user_id) do
    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id and v.metadata["cultural_site"] == true,
        select: count(v.id)
      )

    Repo.one(query) || 0
  end

  defp count_sunrise_checkins(user_id) do
    query =
      from(v in UserVisit,
        where: v.user_id == ^user_id and v.metadata["sunrise"] == true,
        select: count(v.id)
      )

    Repo.one(query) || 0
  end

  @doc "Dynamically check and award badges based on user stats"
  def check_and_award_badges(user_id) do
    stats = get_user_badge_stats(user_id)
    all_badges = get_all_badges()

    earned_badge_types = get_user_badges(user_id) |> Enum.map(fn ub -> ub.badge_type end)

    new_badges =
      Enum.filter(all_badges, fn badge ->
        badge.type not in earned_badge_types and check_badge_threshold(badge, stats)
      end)

    for badge <- new_badges do
      award_badge_by_id(user_id, badge.id, badge.type, badge.name, badge.icon, badge.description)
    end

    get_user_badges(user_id)
  end

  defp check_badge_threshold(badge, stats) do
    current_value = Map.get(stats, String.to_atom(badge.threshold_field), 0)
    current_value >= badge.threshold_value
  end

  defp award_badge_by_id(user_id, badge_id, badge_type, badge_name, badge_icon, description) do
    case Repo.get_by(UserBadge, user_id: user_id, badge_id: badge_id) do
      nil ->
        %UserBadge{}
        |> UserBadge.changeset(%{
          user_id: user_id,
          badge_id: badge_id,
          badge_type: badge_type,
          badge_name: badge_name,
          badge_icon: badge_icon,
          description: description,
          earned_at: DateTime.utc_now()
        })
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc "Award a specific badge to a user (for manual awarding)"
  def award_specific_badge(user_id, badge_type) do
    case Repo.get_by(Badge, type: badge_type, is_active: true) do
      nil ->
        {:error, :badge_not_found}

      badge ->
        case Repo.get_by(UserBadge, user_id: user_id, badge_id: badge.id) do
          nil ->
            %UserBadge{}
            |> UserBadge.changeset(%{
              user_id: user_id,
              badge_id: badge.id,
              badge_type: badge.type,
              badge_name: badge.name,
              badge_icon: badge.icon,
              description: badge.description,
              earned_at: DateTime.utc_now()
            })
            |> Repo.insert()

          existing ->
            {:ok, existing}
        end
    end
  end
end
