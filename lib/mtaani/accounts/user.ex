defmodule Mtaani.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Pbkdf2

  schema "users" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :password_hash, :string
    field :phone_verified, :boolean, default: false
    field :verification_code, :string
    field :preferences, :map, default: %{}
    field :impact_stats, :map, default: %{
      "local_businesses_supported" => 0,
      "community_revenue" => 0,
      "carbon_saved_kg" => 0
    }

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :phone, :password])
    |> validate_required([:name, :phone])
    |> validate_phone()
    |> unique_constraint(:phone)
    |> put_verification_code()
    |> hash_password()
  end

  def verification_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone_verified, :verification_code])
  end

  defp validate_phone(changeset) do
    changeset
    |> validate_format(:phone, ~r/^07\d{8}$/, message: "must be a valid Kenyan phone number (07xxxxxxxx)")
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