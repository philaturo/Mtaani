defmodule Mtaani.Repo.Migrations.AddUsernameColumn do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
    end

    create index(:users, [:username], unique: true)
  end
end