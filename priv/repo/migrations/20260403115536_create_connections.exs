defmodule Mtaani.Repo.Migrations.CreateConnections do
  use Ecto.Migration

  def change do
    create table(:connections) do
      add :status, :string, default: "pending"
      add :user_id, references(:users), null: false
      add :buddy_id, references(:users), null: false
      timestamps()
    end

    create index(:connections, [:user_id])
    create index(:connections, [:buddy_id])
    create index(:connections, [:status])
    create unique_index(:connections, [:user_id, :buddy_id], name: :connections_user_id_buddy_id_index)
  end
end