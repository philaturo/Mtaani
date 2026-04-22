defmodule Mtaani.Repo.Migrations.AddGroupFieldsToMessages do
  use Ecto.Migration

  def change do
    # Clear existing messages for clean slate
    execute("TRUNCATE TABLE messages CASCADE")

    alter table(:messages) do
      add :group_id, references(:groups, on_delete: :delete_all)
      add :channel_id, references(:group_channels, on_delete: :delete_all)
      add :is_pinned, :boolean, default: false
      add :pinned_by, references(:users, on_delete: :nilify_all)
      add :pinned_at, :utc_datetime_usec
    end

    create index(:messages, [:group_id])
    create index(:messages, [:channel_id])
    create index(:messages, [:is_pinned])
    create index(:messages, [:group_id, :channel_id, :inserted_at])
  end
end
