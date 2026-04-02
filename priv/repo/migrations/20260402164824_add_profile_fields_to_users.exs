defmodule Mtaani.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bio, :text
      add :cover_photo_url, :string
      add :profile_photo_url, :string
      add :is_private, :boolean, default: false
      add :location, :string
      add :website, :string
      add :friends_count, :integer, default: 0
      add :followers_count, :integer, default: 0
      add :following_count, :integer, default: 0
    end

    create table(:friendships) do
      add :user_id, references(:users), null: false
      add :friend_id, references(:users), null: false
      add :status, :string, default: "pending" # pending, accepted, blocked
      timestamps()
    end

    create table(:user_photos) do
      add :user_id, references(:users), null: false
      add :url, :string, null: false
      add :thumbnail_url, :string
      add :caption, :text
      add :is_profile_photo, :boolean, default: false
      add :is_cover_photo, :boolean, default: false
      add :album_name, :string
      timestamps()
    end

    create table(:user_albums) do
      add :user_id, references(:users), null: false
      add :name, :string, null: false
      add :description, :text
      add :cover_photo_url, :string
      timestamps()
    end

    create index(:friendships, [:user_id])
    create index(:friendships, [:friend_id])
    create index(:friendships, [:status])
    create index(:user_photos, [:user_id])
    create index(:user_albums, [:user_id])
  end
end