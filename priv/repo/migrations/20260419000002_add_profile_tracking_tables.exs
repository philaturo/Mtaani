defmodule Mtaani.Repo.Migrations.AddProfileTrackingTables do
  use Ecto.Migration

  def change do
    # User visits table
    create table(:user_visits, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :place_id, references(:places, on_delete: :nilify_all)
      add :place_name, :string
      add :county, :string
      add :visit_type, :string, null: false
      add :visited_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:user_visits, [:user_id])
    create index(:user_visits, [:user_id, :county])

    # Add columns to users
    alter table(:users) do
      add :trips_count, :integer, default: 0
      add :counties_visited_count, :integer, default: 0
      add :tours_led, :integer, default: 0
      add :travel_vibes, {:array, :string}, default: []
      add :id_verified, :boolean, default: false
    end

    # Create user_badges table FIRST (before badges table references it)
    create table(:user_badges, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :badge_id, references(:badges, on_delete: :delete_all)
      add :badge_type, :string, null: false
      add :badge_name, :string, null: false
      add :badge_icon, :string
      add :description, :string
      add :earned_at, :utc_datetime, default: fragment("NOW()")
      timestamps()
    end

    create index(:user_badges, [:user_id])
    create index(:user_badges, [:badge_id])
    create unique_index(:user_badges, [:user_id, :badge_type])
  end
end
