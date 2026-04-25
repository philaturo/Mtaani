defmodule Mtaani.Plan.ItineraryItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Plan.Trip

  schema "itinerary_items" do
    field(:day_number, :integer)
    field(:title, :string)
    field(:type, :string)
    field(:start_time, :time)
    field(:duration_hours, :float, default: 1.0)
    field(:location, :string)
    field(:cost, :integer, default: 0)
    field(:votes_count, :integer, default: 0)
    field(:status, :string, default: "pending")
    field(:order_index, :integer, default: 0)

    belongs_to(:trip, Trip)
    belongs_to(:guide, User, foreign_key: :guide_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :trip_id,
      :day_number,
      :title,
      :type,
      :start_time,
      :duration_hours,
      :location,
      :cost,
      :guide_id,
      :votes_count,
      :status,
      :order_index
    ])
    |> validate_required([:trip_id, :day_number, :title, :type])
    |> validate_inclusion(:type, ["transport", "activity", "food", "stay", "exploration"])
    |> validate_inclusion(:status, ["pending", "confirmed", "cancelled"])
    |> validate_number(:day_number, greater_than: 0)
    |> validate_number(:cost, greater_than_or_equal_to: 0)
  end
end
