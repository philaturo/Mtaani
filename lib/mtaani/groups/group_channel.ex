defmodule Mtaani.Groups.GroupChannel do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Groups.{Group, GroupMessage}

  schema "group_channels" do
    belongs_to(:group, Group, foreign_key: :group_id)

    field(:name, :string)
    field(:description, :string)
    field(:channel_order, :integer, default: 0)

    has_many(:messages, GroupMessage, foreign_key: :channel_id)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: :updated_at)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:group_id, :name, :description, :channel_order])
    |> validate_required([:group_id, :name])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_number(:channel_order, greater_than_or_equal_to: 0)
    |> unique_constraint([:group_id, :name])
    |> assoc_constraint(:group)
  end
end
