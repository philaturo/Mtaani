defmodule Mtaani.Plan.TripParticipant do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Plan.Trip

  schema "trip_participants" do
    field(:role, :string, default: "member")
    field(:committed_amount, :integer, default: 0)
    field(:payment_status, :string, default: "pending")
    field(:has_voted, :boolean, default: false)

    belongs_to(:trip, Trip)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :trip_id,
      :user_id,
      :role,
      :committed_amount,
      :payment_status,
      :has_voted
    ])
    |> validate_required([:trip_id, :user_id])
    |> validate_inclusion(:role, ["admin", "member"])
    |> validate_inclusion(:payment_status, ["pending", "paid", "refunded"])
    |> unique_constraint([:trip_id, :user_id])
  end
end
