defmodule Mtaani.Repo.Migrations.RemoveImpactStatsFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :impact_stats
    end
  end
end