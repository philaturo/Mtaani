defmodule Mtaani.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Pbkdf2

  schema "users" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :phone_verified, :boolean, default: false
    field :verification_code, :string
    field :preferences, :map, default: %{}
    
    # Profile fields
    field :bio, :string
    field :cover_photo_url, :string
    field :profile_photo_url, :string
    field :is_private, :boolean, default: false
    field :location, :string
    field :website, :string
    field :friends_count, :integer, default: 0
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0
    field :username, :string

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :username, :email, :phone, :password])
    |> validate_required([:name, :username, :phone, :password])
    |> validate_username()
    |> validate_phone()
    |> unique_constraint(:phone)
    |> unique_constraint(:username)
    |> put_verification_code()
    |> hash_password()
  end

  def verification_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone_verified, :verification_code])
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:bio, :location, :website, :is_private])
  end

  def update_photo(user, photo_url, type) do
    changeset = case type do
      "profile" -> change(user, %{profile_photo_url: photo_url})
      "cover" -> change(user, %{cover_photo_url: photo_url})
    end
    Mtaani.Repo.update(changeset)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]{3,20}$/, 
        message: "must be 3-20 characters, letters, numbers, or underscore")
  end

  defp validate_phone(changeset) do
    changeset
    |> validate_format(:phone, ~r/^\+2547\d{8}$/, message: "must be a valid Kenyan phone number (+2547XXXXXXXX)")
  end

  defp put_verification_code(changeset) do
    code = Mtaani.Accounts.generate_verification_code()
    put_change(changeset, :verification_code, code)
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, hash_pwd_salt(password))
    end
  end

  def verify_password(password, hash) do
    Pbkdf2.verify_pass(password, hash)
  end
end