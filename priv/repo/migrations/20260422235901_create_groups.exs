defmodule Mtaani.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    # Drop the old groups table (from chat_tables migration)
    drop_if_exists table(:groups)

    # Create our new groups table with full features
    create table(:groups) do
      add :name, :string, size: 255, null: false
      add :description, :text
      add :type, :string, size: 50, default: "community"
      add :cover_photo_url, :string, size: 255
      add :location, :string, size: 255
      add :location_lat, :float
      add :location_lng, :float
      add :member_count, :integer, default: 0
      add :online_count, :integer, default: 0
      add :trust_score, :integer, default: 0
      add :is_active, :boolean, default: true
      add :created_by, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:groups, [:type])
    create index(:groups, [:location_lat, :location_lng])
    create index(:groups, [:created_by])
    create index(:groups, [:is_active])
    create index(:groups, [:member_count])
  end
end
