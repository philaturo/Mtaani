defmodule Mtaani.Repo.Migrations.CreateEventAttendees do
  use Ecto.Migration

  def change do
    create table(:event_attendees) do
      add :event_id, references(:group_events, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, size: 20, default: "interested"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_attendees, [:event_id, :user_id])
    create index(:event_attendees, [:event_id])
    create index(:event_attendees, [:user_id])
    create index(:event_attendees, [:status])
  end
end
