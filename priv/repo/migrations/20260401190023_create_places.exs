defmodule Mtaani.Repo.Migrations.CreatePlaces do
  use Ecto.Migration

  def change do
    create table(:places) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :description, :text
      add :address, :string
      add :phone, :string
      add :email, :string
      add :website, :string
      add :hours, :map
      add :price_range, :string
      add :safety_score, :float, default: 0.0
      add :verified, :boolean, default: false
      add :community_impact_score, :integer, default: 0
      add :location, :geometry

      timestamps()
    end

    create index(:places, [:category])
    create index(:places, [:verified])
    create index(:places, [:safety_score])
    create index(:places, [:location], using: :gist)
  end
end