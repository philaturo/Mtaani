defmodule Mtaani.Repo.Migrations.CreateConvoyParticipants do
  use Ecto.Migration

  def change do
    create table(:convoy_participants) do
      add :convoy_id, references(:group_convoys, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :is_sharing_location, :boolean, default: false
      add :current_lat, :float
      add :current_lng, :float
      add :last_location_update, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:convoy_participants, [:convoy_id, :user_id])
    create index(:convoy_participants, [:convoy_id])
    create index(:convoy_participants, [:user_id])
    create index(:convoy_participants, [:is_sharing_location])
    create index(:convoy_participants, [:last_location_update])
  end
end
