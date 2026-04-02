defmodule Mtaani.Repo.Migrations.CreateChatTables do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string, null: false
      add :description, :text
      add :created_by, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:messages) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      timestamps()
    end

    create index(:messages, [:group_id])
    create index(:messages, [:user_id])
  end
end