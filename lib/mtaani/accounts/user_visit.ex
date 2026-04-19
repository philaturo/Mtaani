defmodule Mtaani.Accounts.UserVisit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_visits" do
    field(:place_name, :string)
    field(:county, :string)
    # 'trip', 'check_in', 'post_location'
    field(:visit_type, :string)
    field(:visited_at, :utc_datetime)
    field(:metadata, :map, default: %{})

    belongs_to(:user, Mtaani.Accounts.User)
    belongs_to(:place, Mtaani.Places.Place)

    timestamps()
  end

  def changeset(visit, attrs) do
    visit
    |> cast(attrs, [
      :user_id,
      :place_id,
      :place_name,
      :county,
      :visit_type,
      :visited_at,
      :metadata
    ])
    |> validate_required([:user_id, :visit_type, :visited_at])
    |> validate_inclusion(:visit_type, ["trip", "check_in", "post_location"])
  end
end
