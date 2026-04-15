defmodule Mtaani.Chat do
  @moduledoc """
  The Chat context for managing conversations and messages.
  """

  import Ecto.Query, warn: false
  alias Mtaani.Repo
  alias Mtaani.Chat.Message
  alias Mtaani.Chat.Conversation
  alias Mtaani.Chat.ConversationParticipant
  alias Mtaani.Accounts.User

  # Conversation functions
  def get_or_create_direct_conversation(user1_id, user2_id) do
    # Check if conversation already exists
    query =
      from(cp in ConversationParticipant,
        join: cp2 in ConversationParticipant,
        on: cp.conversation_id == cp2.conversation_id,
        where: cp.user_id == ^user1_id and cp2.user_id == ^user2_id,
        where: cp.conversation_id == cp2.conversation_id,
        select: cp.conversation_id
      )

    case Repo.one(query) do
      nil ->
        # Create new conversation
        {:ok, conversation} = create_conversation(%{type: "direct"})

        # Add participants
        create_participant(%{conversation_id: conversation.id, user_id: user1_id})
        create_participant(%{conversation_id: conversation.id, user_id: user2_id})

        {:ok, conversation}

      conv_id ->
        {:ok, Repo.get(Conversation, conv_id)}
    end
  end

  def create_conversation(attrs \\ %{}) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  def create_participant(attrs \\ %{}) do
    %ConversationParticipant{}
    |> ConversationParticipant.changeset(attrs)
    |> Repo.insert()
  end

  def list_user_conversations(user_id) do
    query =
      from(cp in ConversationParticipant,
        join: c in assoc(cp, :conversation),
        where: cp.user_id == ^user_id,
        order_by: [desc: c.last_message_at],
        preload: [conversation: [:participants]]
      )

    Repo.all(query)
  end

  def update_last_message(conversation_id, message_content, timestamp) do
    query = from(c in Conversation, where: c.id == ^conversation_id)
    Repo.update_all(query, set: [last_message: message_content, last_message_at: timestamp])
  end

  def mark_conversation_read(conversation_id, user_id, read_at \\ DateTime.utc_now()) do
    query =
      from(cp in ConversationParticipant,
        where: cp.conversation_id == ^conversation_id and cp.user_id == ^user_id
      )

    Repo.update_all(query, set: [last_read_at: read_at])
  end

  def get_unread_count(conversation_id, user_id) do
    query =
      from(m in Message,
        join: cp in ConversationParticipant,
        on: cp.conversation_id == m.conversation_id,
        where: m.conversation_id == ^conversation_id,
        where: cp.user_id == ^user_id,
        where: m.inserted_at > cp.last_read_at or is_nil(cp.last_read_at),
        where: m.user_id != ^user_id,
        select: count(m.id)
      )

    Repo.one(query) || 0
  end

  # Message functions
  def create_message(attrs \\ %{}) do
    result =
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()

    # Update conversation last message
    case result do
      {:ok, msg} ->
        update_last_message(msg.conversation_id, msg.content, msg.inserted_at)
        {:ok, msg}

      error ->
        error
    end
  end

  def mark_delivered(message_id, delivered_at \\ DateTime.utc_now()) do
    query = from(m in Message, where: m.id == ^message_id)
    Repo.update_all(query, set: [delivered_at: delivered_at])
  end

  def mark_read(message_id, user_id, read_at \\ DateTime.utc_now()) do
    # Update message read_at
    query = from(m in Message, where: m.id == ^message_id)
    Repo.update_all(query, set: [read_at: read_at])

    # Update conversation participant last_read_at
    message = Repo.get(Message, message_id)

    if message do
      mark_conversation_read(message.conversation_id, user_id, read_at)
    end

    {:ok, read_at}
  end

  def list_messages(conversation_id, limit \\ 50) do
    query =
      from(m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [asc: m.inserted_at],
        limit: ^limit,
        preload: [:user]
      )

    Repo.all(query)
  end
end
