defmodule Mtaani.Chat.ConversationParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_participants" do
    belongs_to(:conversation, Mtaani.Chat.Conversation)
    belongs_to(:user, Mtaani.Accounts.User)
    field(:last_read_at, :utc_datetime)
    field(:is_muted, :boolean, default: false)

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:conversation_id, :user_id, :last_read_at, :is_muted])
    |> validate_required([:conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id], name: :unique_conversation_participant)
  end
end
