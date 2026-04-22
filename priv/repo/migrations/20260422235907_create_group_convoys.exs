defmodule Mtaani.Repo.Migrations.CreateGroupConvoys do
  use Ecto.Migration

  def change do
    create table(:group_convoys) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :name, :string, size: 255, null: false
      add :destination, :string, size: 255
      add :destination_lat, :float
      add :destination_lng, :float
      add :departure_time, :utc_datetime_usec
      add :is_active, :boolean, default: true
      add :created_by, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:group_convoys, [:group_id])
    create index(:group_convoys, [:is_active])
    create index(:group_convoys, [:group_id, :is_active])
  end
end
