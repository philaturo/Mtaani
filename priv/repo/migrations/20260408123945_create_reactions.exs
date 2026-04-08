defmodule Mtaani.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions) do
      add :emoji, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :post_id, references(:posts, on_delete: :delete_all)
      add :message_id, references(:messages, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:reactions, [:user_id, :post_id, :emoji], where: "post_id IS NOT NULL", name: "unique_user_post_reaction")
    create unique_index(:reactions, [:user_id, :message_id, :emoji], where: "message_id IS NOT NULL", name: "unique_user_message_reaction")
    create index(:reactions, [:post_id])
    create index(:reactions, [:message_id])
  end
end