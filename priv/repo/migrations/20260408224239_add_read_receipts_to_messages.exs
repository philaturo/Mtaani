defmodule Mtaani.Repo.Migrations.AddReadReceiptsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :delivered_at, :utc_datetime
      add :read_at, :utc_datetime
    end

    create index(:messages, [:delivered_at])
    create index(:messages, [:read_at])
  end
end