defmodule Mtaani.Repo.Migrations.AddAlbumIdToUserPhotos do
  use Ecto.Migration

  def change do
    alter table(:user_photos) do
      add :album_id, references(:user_albums, on_delete: :nilify_all)
    end

    create index(:user_photos, [:album_id])
  end
end
