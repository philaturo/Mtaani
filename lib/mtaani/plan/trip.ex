defmodule Mtaani.Plan.Trip do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Places.Place
  alias Mtaani.Groups.Group
  alias Mtaani.Plan.{TripParticipant, ItineraryItem, BudgetItem, PackingItem, VibePin}

  schema "trips" do
    field(:name, :string)
    field(:destination, :string)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:budget_per_person, :integer)
    field(:vibe_tags, {:array, :string}, default: [])
    field(:status, :string, default: "planning")
    field(:progress_percentage, :integer, default: 0)
    field(:cover_emoji, :string, default: "✈️")
    field(:total_budget_committed, :integer, default: 0)

    belongs_to(:creator, User, foreign_key: :creator_id)
    belongs_to(:destination_place, Place, foreign_key: :destination_place_id)
    belongs_to(:group, Group, foreign_key: :group_id)

    has_many(:participants, TripParticipant, foreign_key: :trip_id)
    has_many(:itinerary_items, ItineraryItem, foreign_key: :trip_id)
    has_many(:budget_items, BudgetItem, foreign_key: :trip_id)
    has_many(:packing_items, PackingItem, foreign_key: :trip_id)
    has_many(:vibe_pins, VibePin, foreign_key: :trip_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [
      :name,
      :destination,
      :destination_place_id,
      :start_date,
      :end_date,
      :budget_per_person,
      :vibe_tags,
      :status,
      :progress_percentage,
      :cover_emoji,
      :total_budget_committed,
      :group_id,
      :creator_id
    ])
    |> validate_required([:name, :destination, :start_date, :end_date, :creator_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_inclusion(:status, ["planning", "active", "completed", "cancelled"])
    |> validate_number(:budget_per_person, greater_than_or_equal_to: 0)
    |> validate_number(:progress_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_dates()
  end

  defp validate_dates(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && end_date < start_date do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end
end
