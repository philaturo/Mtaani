defmodule Mtaani.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string
      add :phone, :string, null: false
      add :password_hash, :string
      add :phone_verified, :boolean, default: false
      add :verification_code, :string
      add :preferences, :map, default: %{}
      add :impact_stats, :map, default: %{
        "local_businesses_supported" => 0,
        "community_revenue" => 0,
        "carbon_saved_kg" => 0
      }

      timestamps()
    end

    create unique_index(:users, [:phone])
    create index(:users, [:phone_verified])
  end
end