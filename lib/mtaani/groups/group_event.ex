defmodule Mtaani.Groups.GroupEvent do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.{Group, EventAttendee}

  schema "group_events" do
    belongs_to(:group, Group, foreign_key: :group_id)

    field(:title, :string)
    field(:description, :string)
    field(:event_date, :utc_datetime_usec)
    field(:location, :string)
    field(:location_lat, :float)
    field(:location_lng, :float)
    field(:max_attendees, :integer)
    field(:attendees_count, :integer, default: 0)

    belongs_to(:created_by, User, foreign_key: :created_by_id)
    has_many(:attendees, EventAttendee, foreign_key: :event_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :group_id,
      :title,
      :description,
      :event_date,
      :location,
      :location_lat,
      :location_lng,
      :max_attendees,
      :attendees_count,
      :created_by_id
    ])
    |> validate_required([:group_id, :title, :event_date])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_number(:attendees_count, greater_than_or_equal_to: 0)
    |> validate_number(:max_attendees, greater_than_or_equal_to: 1, less_than_or_equal_to: 10000)
    |> assoc_constraint(:group)
    |> assoc_constraint(:created_by)
  end
end
