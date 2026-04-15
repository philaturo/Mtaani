defmodule Mtaani.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    # Create conversations table
    create table(:conversations) do
      add :type, :string, default: "direct", null: false  # direct, group
      add :name, :string  # For group chats
      add :last_message, :text
      add :last_message_at, :utc_datetime
      add :is_pinned, :boolean, default: false
      add :created_by, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:conversations, [:type])
    create index(:conversations, [:last_message_at])

    # Create conversation_participants table
    create table(:conversation_participants) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime
      add :is_muted, :boolean, default: false

      timestamps()
    end

    create unique_index(:conversation_participants, [:conversation_id, :user_id], name: :unique_conversation_participant)
    create index(:conversation_participants, [:user_id])
    create index(:conversation_participants, [:last_read_at])

    # Add conversation_id to messages
    alter table(:messages) do
      remove :group_id
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
    end

    create index(:messages, [:conversation_id])
  end
end
