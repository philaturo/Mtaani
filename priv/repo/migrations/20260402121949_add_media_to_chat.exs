defmodule Mtaani.Repo.Migrations.AddMediaToChat do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :media_url, :string
      add :media_type, :string
      add :media_thumbnail, :string
      add :is_deleted, :boolean, default: false
      add :is_edited, :boolean, default: false
      add :reply_to_id, references(:messages)
    end

    create table(:user_statuses) do
      add :media_url, :string, null: false
      add :media_type, :string, null: false
      add :caption, :text
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users), null: false
      timestamps()
    end

    create index(:user_statuses, [:user_id])
    create index(:user_statuses, [:expires_at])
  end
end