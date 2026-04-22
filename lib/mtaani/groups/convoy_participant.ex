defmodule Mtaani.Groups.ConvoyParticipant do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.GroupConvoy

  schema "convoy_participants" do
    belongs_to(:convoy, GroupConvoy, foreign_key: :convoy_id)
    belongs_to(:user, User, foreign_key: :user_id)

    field(:is_sharing_location, :boolean, default: false)
    field(:current_lat, :float)
    field(:current_lng, :float)
    field(:last_location_update, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :convoy_id,
      :user_id,
      :is_sharing_location,
      :current_lat,
      :current_lng,
      :last_location_update
    ])
    |> validate_required([:convoy_id, :user_id])
    |> validate_number(:current_lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:current_lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> unique_constraint([:convoy_id, :user_id])
    |> assoc_constraint(:convoy)
    |> assoc_constraint(:user)
  end

  def update_location_changeset(participant, lat, lng) do
    participant
    |> change()
    |> put_change(:current_lat, lat)
    |> put_change(:current_lng, lng)
    |> put_change(:last_location_update, DateTime.utc_now())
  end
end
