defmodule Mtaani.Repo.Migrations.CreateGroupEvents do
  use Ecto.Migration

  def change do
    create table(:group_events) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :title, :string, size: 255, null: false
      add :description, :text
      add :event_date, :utc_datetime_usec, null: false
      add :location, :string, size: 255
      add :location_lat, :float
      add :location_lng, :float
      add :max_attendees, :integer
      add :attendees_count, :integer, default: 0
      add :created_by, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:group_events, [:group_id])
    create index(:group_events, [:event_date])
    create index(:group_events, [:group_id, :event_date])
  end
end
