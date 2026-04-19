defmodule Mtaani.Accounts.Guide do
  use Ecto.Schema
  import Ecto.Changeset

  schema "guides" do
    field(:bio, :string)
    field(:hourly_rate, :decimal)
    field(:languages, {:array, :string}, default: [])
    field(:years_experience, :integer, default: 0)
    field(:total_tours, :integer, default: 0)
    field(:rating, :decimal, default: 0.0)
    field(:reviews_count, :integer, default: 0)
    field(:availability_status, :string, default: "offline")
    field(:verification_status, :string, default: "pending")
    field(:verified_at, :utc_datetime)

    belongs_to(:user, Mtaani.Accounts.User)

    timestamps()
  end

  def changeset(guide, attrs) do
    guide
    |> cast(attrs, [
      :bio,
      :hourly_rate,
      :languages,
      :years_experience,
      :total_tours,
      :rating,
      :reviews_count,
      :availability_status,
      :verification_status,
      :verified_at,
      :user_id
    ])
    |> validate_required([:user_id])
    |> validate_number(:hourly_rate, greater_than_or_equal_to: 0)
    |> validate_number(:rating, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
  end
end
