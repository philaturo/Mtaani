defmodule Mtaani.Incidents.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  schema "incidents" do
    field :type, :string
    field :severity, :integer
    field :description, :string
    field :source, :string
     field :location, :map
    field :resolved, :boolean, default: false
    field :reported_at, :utc_datetime
    
    timestamps()
  end

  def changeset(incident, attrs) do
    incident
    |> cast(attrs, [:type, :severity, :description, :source, :location, :resolved, :reported_at])
    |> validate_required([:type, :severity, :location])
  end
end