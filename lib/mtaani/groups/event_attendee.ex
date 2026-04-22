defmodule Mtaani.Groups.EventAttendee do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.GroupEvent

  schema "event_attendees" do
    belongs_to(:event, GroupEvent, foreign_key: :event_id)
    belongs_to(:user, User, foreign_key: :user_id)

    field(:status, :string, default: "interested")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :user_id, :status])
    |> validate_required([:event_id, :user_id])
    |> validate_inclusion(:status, ["going", "interested", "not_going"])
    |> unique_constraint([:event_id, :user_id])
    |> assoc_constraint(:event)
    |> assoc_constraint(:user)
  end
end
