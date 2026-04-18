defmodule Mtaani.Repo.Migrations.AddReactionsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :reactions, :map, default: %{}
    end
  end
end
