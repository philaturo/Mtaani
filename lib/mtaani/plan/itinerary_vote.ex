defmodule Mtaani.Plan.ItineraryVote do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Plan.ItineraryItem

  schema "itinerary_votes" do
    field(:vote_type, :string, default: "up")

    belongs_to(:itinerary_item, ItineraryItem)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:itinerary_item_id, :user_id, :vote_type])
    |> validate_required([:itinerary_item_id, :user_id])
    |> validate_inclusion(:vote_type, ["up", "down"])
    |> unique_constraint([:itinerary_item_id, :user_id])
  end
end
