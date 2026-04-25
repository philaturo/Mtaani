defmodule Mtaani.Repo.Migrations.CreateTrips do
  use Ecto.Migration

  def change do
    create table(:trips, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :name, :string, null: false
      add :destination, :string, null: false
      add :destination_place_id, references(:places, on_delete: :nothing)
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :budget_per_person, :integer
      add :vibe_tags, {:array, :string}, default: []
      add :status, :string, default: "planning" # planning, active, completed, cancelled
      add :progress_percentage, :integer, default: 0
      add :cover_emoji, :string, default: "✈️"
      add :total_budget_committed, :integer, default: 0
      add :group_id, references(:groups, on_delete: :nothing)
      add :creator_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:trips, [:creator_id])
    create index(:trips, [:destination_place_id])
    create index(:trips, [:group_id])
    create index(:trips, [:status])
    create index(:trips, [:start_date, :end_date])
  end
end
