defmodule Mtaani.Chat do
  @moduledoc """
  The Chat context for managing messages and conversations.
  """

  import Ecto.Query, warn: false
  alias Mtaani.Repo
  alias Mtaani.Chat.Message
  alias Mtaani.Chat.Group

  @doc """
  Marks a message as delivered.
  """
  def mark_delivered(message_id, delivered_at \\ DateTime.utc_now()) do
    query = from m in Message, where: m.id == ^message_id
    Repo.update_all(query, set: [delivered_at: delivered_at])
  end

  @doc """
  Marks a message as read by a user.
  """
  def mark_read(message_id, user_id, read_at \\ DateTime.utc_now()) do
    # Update database
    query = from m in Message, where: m.id == ^message_id
    Repo.update_all(query, set: [read_at: read_at])
    
    # Store in Redis for real-time (optional, will work without Redis)
    if Code.ensure_loaded?(Mtaani.Redis) and function_exported?(Mtaani.Redis, :set_read_status, 3) do
      Mtaani.Redis.set_read_status(message_id, user_id, read_at)
    end
    
    {:ok, read_at}
  end

  @doc """
  Gets unread message count for a user in a chat.
  """
  def get_unread_count(chat_id, user_id) do
    query = from m in Message,
      where: m.group_id == ^chat_id,
      where: m.user_id != ^user_id,
      where: is_nil(m.read_at),
      select: count(m.id)
    
    Repo.one(query) || 0
  end

  @doc """
  Returns the list of messages for a conversation.
  """
  def list_messages(chat_id, limit \\ 50) do
    query = from m in Message,
      where: m.group_id == ^chat_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user]
    
    Repo.all(query) |> Enum.reverse()
  end

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end
end