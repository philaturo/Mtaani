defmodule Mtaani.Social.UserAlbum do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_albums" do
    field :name, :string
    field :description, :string
    field :cover_photo_url, :string
    belongs_to :user, Mtaani.Accounts.User
    has_many :photos, Mtaani.Social.UserPhoto, foreign_key: :album_id
    
    timestamps()
  end

  def changeset(album, attrs) do
    album
    |> cast(attrs, [:name, :description, :cover_photo_url, :user_id])
    |> validate_required([:name, :user_id])
  end
end