defmodule Mtaani.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field(:content, :string)
    field(:media_url, :string)
    field(:media_type, :string)
    field(:media_thumbnail, :string)
    field(:is_deleted, :boolean, default: false)
    field(:is_edited, :boolean, default: false)
    field(:reply_to_id, :id)
    field(:delivered_at, :utc_datetime)
    field(:read_at, :utc_datetime)
    field(:reactions, :map, default: %{})

    belongs_to(:user, Mtaani.Accounts.User)
    belongs_to(:conversation, Mtaani.Chat.Conversation)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :content,
      :media_url,
      :media_type,
      :media_thumbnail,
      :is_deleted,
      :is_edited,
      :reply_to_id,
      :user_id,
      :conversation_id,
      :delivered_at,
      :read_at,
      :reactions
    ])
    |> validate_required([:user_id, :conversation_id])
    |> validate_length(:content, max: 2000)
  end
end
