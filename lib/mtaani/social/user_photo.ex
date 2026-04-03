defmodule Mtaani.Social.UserPhoto do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_photos" do
    field :url, :string
    field :thumbnail_url, :string
    field :caption, :string
    field :is_profile_photo, :boolean, default: false
    field :is_cover_photo, :boolean, default: false
    field :album_name, :string
    belongs_to :user, Mtaani.Accounts.User
    belongs_to :album, Mtaani.Social.UserAlbum, foreign_key: :album_id
    
    timestamps()
  end

  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:url, :thumbnail_url, :caption, :is_profile_photo, :is_cover_photo, :album_name, :user_id, :album_id])
    |> validate_required([:url, :user_id])
  end
end