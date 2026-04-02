defmodule Mtaani.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :media_url, :string
    field :media_type, :string  # image, video, audio, document
    field :media_thumbnail, :string
    field :is_deleted, :boolean, default: false
    field :is_edited, :boolean, default: false
    field :reply_to_id, :id
    
    # belongs_to automatically creates user_id and group_id fields
    belongs_to :user, Mtaani.Accounts.User
    belongs_to :group, Mtaani.Chat.Group
    
    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :media_url, :media_type, :media_thumbnail, 
                    :is_deleted, :is_edited, :reply_to_id, :user_id, :group_id])
    |> validate_required([:user_id, :group_id])
    |> validate_length(:content, max: 2000)
  end
end