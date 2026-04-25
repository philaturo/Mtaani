defmodule Mtaani.Repo.Migrations.CreateItineraryVotes do
  use Ecto.Migration

  def change do
    create table(:itinerary_votes, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :itinerary_item_id, references(:itinerary_items, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :vote_type, :string, default: "up" # up, down

      timestamps(type: :utc_datetime)
    end

    create unique_index(:itinerary_votes, [:itinerary_item_id, :user_id])
    create index(:itinerary_votes, [:user_id])
  end
end
