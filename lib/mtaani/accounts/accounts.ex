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
  import Ecto.Query

  # ============ PHONE FORMATTING ============

  defp format_phone(nil), do: nil

  defp format_phone(phone) when is_binary(phone) do
    # Remove all non-digit characters
    digits = String.replace(phone, ~r/\D/, "")

    cond do
      # Already in +254 format with digits
      String.starts_with?(digits, "254") and String.length(digits) == 12 ->
        "+" <> digits

      # Kenyan format: 07XXXXXXXX
      String.starts_with?(digits, "07") and String.length(digits) == 10 ->
        "+254" <> String.slice(digits, 1, 9)

      # Missing leading zero: 7XXXXXXXX
      String.starts_with?(digits, "7") and String.length(digits) == 9 ->
        "+254" <> digits

      true ->
        nil
    end
  end

  defp format_phone(_), do: nil

  # ============ USER LOOKUP ============

  @doc """
  Get a user by phone number.
  """
  def get_user_by_phone(phone) do
    if is_nil(phone) do
      nil
    else
      formatted = format_phone(phone)

      if formatted do
        Repo.get_by(User, phone: formatted)
      else
        nil
      end
    end
  end

  @doc """
  Get a user by ID.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Get a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  # ============ GUIDE MANAGEMENT ============

  @doc """
  Get nearby guides based on user location.
  """
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

  @doc """
  Get count of nearby guides.
  """
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

  @doc """
  Create or update a guide profile.
  """
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

  @doc """
  Get guide by user ID.
  """
  def get_guide_by_user_id(user_id) do
    Repo.get_by(Guide, user_id: user_id)
  end

  @doc """
  Update user profile with complete profile fields (for profile setup).
  """
  def update_complete_profile(user, attrs) do
    user
    |> User.complete_profile_changeset(attrs)
    |> Repo.update()
  end

  # ============ AUTHENTICATION ============

  @doc """
  Authenticate a user by phone and password.
  """
  def authenticate_user(phone, password) do
    user = get_user_by_phone(phone)

    cond do
      is_nil(user) ->
        {:error, "Invalid phone number or password"}

      Pbkdf2.verify_pass(password, user.password_hash) ->
        {:ok, user}

      true ->
        {:error, "Invalid phone number or password"}
    end
  end

  # ============ USER CREATION ============

  @doc """
  Create a new user with phone verification.
  """
  def create_user(attrs) do
    # Convert atom keys to string keys
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

  @doc """
  Update user profile.
  """
  def update_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Update user photo (profile or cover).
  """
  def update_user_photo(user, photo_url, type) do
    User.update_photo(user, photo_url, type)
  end

  # ============ VERIFICATION ============

  @doc """
  Generate a 6-digit verification code.
  """
  def generate_verification_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Send verification code via SMS.
  """
  def send_verification_code(phone, code) do
    IO.puts("SMS to #{phone}: Your Mtaani verification code is: #{code}")
    {:ok, "sent"}
  end

  @doc """
  Verify a user's phone with the provided code.
  """
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

  @doc """
  Get user's travel buddies (accepted connections).
  """
  def get_travel_buddies(user) do
    query =
      from(c in Connection,
        where: c.user_id == ^user.id and c.status == "accepted",
        or_where: c.buddy_id == ^user.id and c.status == "accepted",
        preload: [:user, :buddy]
      )

    Repo.all(query)
    |> Enum.map(fn connection ->
      if connection.user_id == user.id do
        connection.buddy
      else
        connection.user
      end
    end)
  end

  @doc """
  Get suggested travel buddies (users not yet connected).
  """
  def get_suggested_buddies(user, limit \\ 10) do
    buddy_ids = get_travel_buddies(user) |> Enum.map(& &1.id)
    excluded_ids = [user.id | buddy_ids]

    query =
      from(u in User,
        where: u.id not in ^excluded_ids,
        limit: ^limit,
        order_by: [desc: u.inserted_at]
      )

    Repo.all(query)
  end

  @doc """
  Send a connection request to another user.
  """
  def send_connection_request(user_id, buddy_id) do
    %Connection{}
    |> Connection.changeset(%{
      user_id: user_id,
      buddy_id: buddy_id,
      status: "pending"
    })
    |> Repo.insert()
  end

  @doc """
  Accept a connection request.
  """
  def accept_connection_request(request_id) do
    connection = Repo.get(Connection, request_id)

    connection
    |> Connection.changeset(%{status: "accepted"})
    |> Repo.update()
  end

  @doc """
  Decline a connection request.
  """
  def decline_connection_request(request_id) do
    connection = Repo.get(Connection, request_id)

    connection
    |> Connection.changeset(%{status: "declined"})
    |> Repo.update()
  end

  @doc """
  Get pending connection requests for a user.
  """
  def get_pending_requests(user) do
    query =
      from(c in Connection,
        where: c.buddy_id == ^user.id and c.status == "pending",
        preload: [:user]
      )

    Repo.all(query)
  end

  # ============ PHOTO MANAGEMENT ============

  @doc """
  Get user's photos.
  """
  def get_user_photos(user) do
    query =
      from(p in UserPhoto,
        where: p.user_id == ^user.id,
        order_by: [desc: p.inserted_at]
      )

    Repo.all(query)
  end

  @doc """
  Create user album.
  """
  def create_album(user, attrs) do
    %UserAlbum{}
    |> UserAlbum.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
  end

  @doc """
  Add photo to album.
  """
  def add_photo(user, attrs, album_id \\ nil) do
    attrs = Map.put(attrs, :user_id, user.id)
    attrs = if album_id, do: Map.put(attrs, :album_id, album_id), else: attrs

    %UserPhoto{}
    |> UserPhoto.changeset(attrs)
    |> Repo.insert()
  end
end
