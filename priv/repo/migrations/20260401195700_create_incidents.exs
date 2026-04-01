defmodule Mtaani.Repo.Migrations.CreateIncidents do
  use Ecto.Migration

  def change do
    create table(:incidents) do
      add :type, :string, null: false  # traffic, security, weather, etc.
      add :severity, :integer, default: 1  # 1-5
      add :description, :text
      add :source, :string  # police, user, social_media
      add :location, :geometry
      add :resolved, :boolean, default: false
      add :reported_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:incidents, [:type])
    create index(:incidents, [:severity])
    create index(:incidents, [:resolved])
    create index(:incidents, [:location], using: :gist)
  end
end