defmodule Mtaani.Repo.Migrations.CreateSafetyZones do
  use Ecto.Migration

  def change do
    create table(:safety_zones) do
      add :name, :string, null: false
      add :description, :text
      add :safety_level, :integer, default: 2  # 1=calm, 2=bustling, 3=caution
      add :area, :geometry
      add :incident_count, :integer, default: 0
      add :last_updated, :utc_datetime

      timestamps()
    end

    create index(:safety_zones, [:safety_level])
    create index(:safety_zones, [:area], using: :gist)
  end
end