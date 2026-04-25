defmodule Mtaani.Repo.Migrations.CreateItineraryItems do
  use Ecto.Migration

  def change do
    create table(:itinerary_items, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :day_number, :integer, null: false
      add :title, :string, null: false
      add :type, :string, null: false # transport, activity, food, stay, exploration
      add :start_time, :time
      add :duration_hours, :float, default: 1.0
      add :location, :string
      add :cost, :integer, default: 0
      add :guide_id, references(:users, on_delete: :nothing)
      add :votes_count, :integer, default: 0
      add :status, :string, default: "pending" # pending, confirmed, cancelled
      add :order_index, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:itinerary_items, [:trip_id, :day_number])
    create index(:itinerary_items, [:guide_id])
    create index(:itinerary_items, [:type])
    create index(:itinerary_items, [:order_index])
  end
end
