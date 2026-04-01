defmodule Mtaani.Transport.TransportProvider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transport_providers" do
    field :name, :string
    field :type, :string  # uber, bolt, matatu, boda, bus
    field :sacco_name, :string
    field :route_number, :string
    field :stages, {:array, :string}
    field :peak_hours, {:array, :string}
    field :base_fare, :integer
    field :price_per_km, :float
    field :safety_score, :float
    field :verified, :boolean, default: false
    field :contact, :string
    field :logo_url, :string
    field :route_description, :string
    field :frequency_minutes, :integer
    field :wheelchair_accessible, :boolean, default: false
    
    timestamps()
  end

  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :type, :sacco_name, :route_number, :stages, :peak_hours, 
                    :base_fare, :price_per_km, :safety_score, :verified, :contact, 
                    :logo_url, :route_description, :frequency_minutes, :wheelchair_accessible])
    |> validate_required([:name, :type])
  end
end