defmodule Mtaani.Accounts.UserBadge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_badges" do
    field(:badge_type, :string)
    field(:badge_name, :string)
    field(:badge_icon, :string)
    field(:description, :string)
    field(:earned_at, :utc_datetime)

    belongs_to(:user, Mtaani.Accounts.User)
    # New association
    belongs_to(:badge, Mtaani.Accounts.Badge)

    timestamps()
  end

  def changeset(user_badge, attrs) do
    user_badge
    |> cast(attrs, [
      :user_id,
      :badge_id,
      :badge_type,
      :badge_name,
      :badge_icon,
      :description,
      :earned_at
    ])
    |> validate_required([:user_id])
  end
end
