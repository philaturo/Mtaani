defmodule Mtaani.Groups.GroupConvoy do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.{Group, ConvoyParticipant}

  schema "group_convoys" do
    belongs_to(:group, Group, foreign_key: :group_id)

    field(:name, :string)
    field(:destination, :string)
    field(:destination_lat, :float)
    field(:destination_lng, :float)
    field(:departure_time, :utc_datetime_usec)
    field(:is_active, :boolean, default: true)

    belongs_to(:created_by, User, foreign_key: :created_by_id)
    has_many(:participants, ConvoyParticipant, foreign_key: :convoy_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(convoy, attrs) do
    convoy
    |> cast(attrs, [
      :group_id,
      :name,
      :destination,
      :destination_lat,
      :destination_lng,
      :departure_time,
      :is_active,
      :created_by_id
    ])
    |> validate_required([:group_id, :name])
    |> validate_length(:name, min: 3, max: 255)
    |> assoc_constraint(:group)
    |> assoc_constraint(:created_by)
  end
end
