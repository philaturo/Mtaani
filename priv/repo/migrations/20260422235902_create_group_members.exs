defmodule Mtaani.Repo.Migrations.CreateGroupMembers do
  use Ecto.Migration

  def change do
    create table(:group_members) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, size: 20, default: "member"
      add :is_online, :boolean, default: false
      add :last_active, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, inserted_at: :joined_at)
    end

    create unique_index(:group_members, [:group_id, :user_id])
    create index(:group_members, [:group_id])
    create index(:group_members, [:user_id])
    create index(:group_members, [:role])
    create index(:group_members, [:is_online])
  end
end
