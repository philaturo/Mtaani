defmodule Mtaani.Repo.Migrations.CreateTransportProviders do
  use Ecto.Migration

  def change do
    create table(:transport_providers) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :sacco_name, :string
      add :route_number, :string
      add :stages, {:array, :string}
      add :peak_hours, {:array, :string}
      add :base_fare, :integer
      add :price_per_km, :float
      add :safety_score, :float
      add :verified, :boolean, default: false
      add :contact, :string
      add :logo_url, :string
      
      timestamps()
    end

    create index(:transport_providers, [:type])
    create index(:transport_providers, [:verified])
    create index(:transport_providers, [:sacco_name])
  end
end