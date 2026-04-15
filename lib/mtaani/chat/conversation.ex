defmodule Mtaani.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field(:type, :string, default: "direct")
    field(:name, :string)
    field(:last_message, :string)
    field(:last_message_at, :utc_datetime)
    field(:is_pinned, :boolean, default: false)
    belongs_to(:created_by, Mtaani.Accounts.User)
    has_many(:participants, Mtaani.Chat.ConversationParticipant)
    has_many(:messages, Mtaani.Chat.Message)

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:type, :name, :last_message, :last_message_at, :is_pinned, :created_by_id])
    |> validate_required([:type])
  end
end
