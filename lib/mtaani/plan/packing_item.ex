defmodule Mtaani.Plan.PackingItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Plan.Trip

  schema "packing_items" do
    field(:name, :string)
    field(:category, :string, default: "general")
    field(:is_checked, :boolean, default: false)
    field(:is_ai_suggested, :boolean, default: false)
    field(:order_index, :integer, default: 0)

    belongs_to(:trip, Trip)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :trip_id,
      :name,
      :category,
      :is_checked,
      :is_ai_suggested,
      :order_index
    ])
    |> validate_required([:trip_id, :name])
    |> validate_inclusion(:category, [
      "clothing",
      "gear",
      "documents",
      "health",
      "electronics",
      "general"
    ])
  end
end
