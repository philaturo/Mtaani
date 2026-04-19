defmodule Mtaani.Repo.Migrations.AddGuideFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :traveler_type, :string, size: 50
      add :is_guide, :boolean, default: false
      add :location_lat, :float
      add :location_lng, :float
      add :last_active, :utc_datetime
    end

    create index(:users, [:traveler_type])
    create index(:users, [:is_guide])
  end
end
