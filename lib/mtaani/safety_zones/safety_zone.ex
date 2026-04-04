defmodule Mtaani.SafetyZones.SafetyZone do
  use Ecto.Schema
  import Ecto.Changeset

  schema "safety_zones" do
    field :name, :string
    field :description, :string
    field :incident_count, :integer, default: 0
    field :area, :map
    field :last_updated, :utc_datetime
    
    timestamps()
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :description, :incident_count, :area, :last_updated])
    |> validate_required([:name, :area])
  end
end