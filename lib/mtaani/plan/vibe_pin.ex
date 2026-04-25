defmodule Mtaani.Plan.VibePin do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Plan.Trip

  schema "vibe_pins" do
    field(:image_url, :string)
    field(:emoji, :string)
    field(:caption, :string)
    field(:vibe_tag, :string)

    belongs_to(:trip, Trip)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def changeset(pin, attrs) do
    pin
    |> cast(attrs, [:trip_id, :user_id, :image_url, :emoji, :caption, :vibe_tag])
    |> validate_required([:trip_id, :user_id])
    |> validate_length(:caption, max: 200)
  end
end
