defmodule Mtaani.Groups.GroupMessage do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.{Group, GroupChannel}

  schema "messages" do
    field(:content, :string)
    belongs_to(:user, User, foreign_key: :user_id)

    belongs_to(:group, Group, foreign_key: :group_id)
    belongs_to(:channel, GroupChannel, foreign_key: :channel_id)

    field(:media_url, :string)
    field(:media_type, :string)
    field(:media_thumbnail, :string)
    field(:is_deleted, :boolean, default: false)
    field(:is_edited, :boolean, default: false)

    belongs_to(:reply_to, __MODULE__, foreign_key: :reply_to_id)

    field(:delivered_at, :utc_datetime_usec)
    field(:read_at, :utc_datetime_usec)

    belongs_to(:conversation, Mtaani.Chat.Conversation, foreign_key: :conversation_id)

    field(:reactions, :map, default: %{})

    field(:is_pinned, :boolean, default: false)
    belongs_to(:pinned_by, User, foreign_key: :pinned_by_id)
    field(:pinned_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :content,
      :user_id,
      :group_id,
      :channel_id,
      :media_url,
      :media_type,
      :media_thumbnail,
      :is_deleted,
      :is_edited,
      :reply_to_id,
      :delivered_at,
      :read_at,
      :conversation_id,
      :reactions,
      :is_pinned,
      :pinned_by_id,
      :pinned_at
    ])
    |> validate_required([:content, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
    |> assoc_constraint(:user)
    |> assoc_constraint(:group)
    |> assoc_constraint(:channel)
  end

  def group_message_changeset(message, attrs, user_id, group_id, channel_id) do
    message
    |> changeset(Map.put(attrs, :user_id, user_id))
    |> put_change(:group_id, group_id)
    |> put_change(:channel_id, channel_id)
  end
end
