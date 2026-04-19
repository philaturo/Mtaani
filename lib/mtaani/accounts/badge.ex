defmodule Mtaani.Accounts.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "badges" do
    field(:type, :string)
    field(:name, :string)
    field(:icon, :string)
    field(:description, :string)
    field(:threshold_field, :string)
    field(:threshold_value, :integer)
    field(:category, :string)
    field(:is_active, :boolean, default: true)

    has_many(:user_badges, Mtaani.Accounts.UserBadge)

    timestamps()
  end

  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [
      :type,
      :name,
      :icon,
      :description,
      :threshold_field,
      :threshold_value,
      :category,
      :is_active
    ])
    |> validate_required([:type, :name, :threshold_field, :threshold_value])
    |> unique_constraint(:type)
  end
end
