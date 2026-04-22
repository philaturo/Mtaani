defmodule Mtaani.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.{GroupMember, GroupChannel, GroupEvent, GroupConvoy}

  schema "groups" do
    field(:name, :string)
    field(:description, :string)
    field(:type, :string, default: "community")
    field(:cover_photo_url, :string)
    field(:location, :string)
    field(:location_lat, :float)
    field(:location_lng, :float)
    field(:member_count, :integer, default: 0)
    field(:online_count, :integer, default: 0)
    field(:trust_score, :integer, default: 0)
    field(:is_active, :boolean, default: true)

    belongs_to(:created_by, User, foreign_key: :created_by_id)
    has_many(:members, GroupMember, foreign_key: :group_id)
    has_many(:channels, GroupChannel, foreign_key: :group_id)
    has_many(:events, GroupEvent, foreign_key: :group_id)
    has_many(:convoys, GroupConvoy, foreign_key: :group_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :description,
      :type,
      :cover_photo_url,
      :location,
      :location_lat,
      :location_lng,
      :member_count,
      :online_count,
      :trust_score,
      :is_active,
      :created_by_id
    ])
    |> validate_required([:name, :created_by_id])
    |> validate_inclusion(:type, ["trip", "community", "guide_network", "private"])
    |> validate_length(:name, min: 3, max: 255)
    |> validate_number(:trust_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:member_count, greater_than_or_equal_to: 0)
    |> validate_number(:online_count, greater_than_or_equal_to: 0)
  end

  def create_changeset(group, attrs, creator_id) do
    group
    |> changeset(Map.put(attrs, :created_by_id, creator_id))
    |> put_change(:member_count, 1)
    |> put_change(:trust_score, 0)
  end
end
