defmodule Mtaani.Chat.UserStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_statuses" do
    field :media_url, :string
    field :media_type, :string  # image, video
    field :caption, :string
    field :expires_at, :utc_datetime
    
    belongs_to :user, Mtaani.Accounts.User
    
    timestamps()
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:media_url, :media_type, :caption, :expires_at, :user_id])
    |> validate_required([:media_url, :media_type, :user_id])
    |> validate_inclusion(:media_type, ["image", "video"])
  end
end