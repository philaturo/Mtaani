defmodule Mtaani.Repo.Migrations.AddInteractionCountsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :likes_count, :integer, default: 0
      add :reposts_count, :integer, default: 0
      add :comments_count, :integer, default: 0
      add :bookmarks_count, :integer, default: 0
    end
  end
end