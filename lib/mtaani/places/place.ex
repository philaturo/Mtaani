defmodule Mtaani.Places.Place do
  use Ecto.Schema
  import Ecto.Changeset

  schema "places" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :address, :string
    field :phone, :string
    field :price_range, :string
    field :verified, :boolean, default: false
    field :location, :map 
    
    timestamps()
  end

  def changeset(place, attrs) do
    place
    |> cast(attrs, [:name, :category, :description, :address, :phone, 
                    :price_range, :verified, :location])
    |> validate_required([:name, :category, :location])
  end
end