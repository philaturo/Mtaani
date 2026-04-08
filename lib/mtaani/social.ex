defmodule Mtaani.Social do
  @moduledoc """
  The Social context for posts, comments, likes, and reactions.
  """

  import Ecto.Query, warn: false
  alias Mtaani.Repo
  alias Mtaani.Social.Post
  alias Mtaani.Social.Reaction

  @reaction_emojis ["❤️", "👍", "😂", "😮", "😢", "🙏"]

  @doc """
  Returns the list of posts.
  """
  def list_posts do
    Repo.all(Post)
  end

  @doc """
  Gets a single post by ID.
  """
  def get_post!(id), do: Repo.get!(Post, id)

  @doc """
  Creates a post.
  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.
  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  # ==================== REACTION FUNCTIONS ====================

  @doc """
  Lists all reactions for a post.
  """
  def list_reactions_for_post(post_id) do
    query = from r in Reaction,
      where: r.post_id == ^post_id,
      preload: [:user]
    Repo.all(query)
  end

  @doc """
  Lists all reactions for a message.
  """
  def list_reactions_for_message(message_id) do
    query = from r in Reaction,
      where: r.message_id == ^message_id,
      preload: [:user]
    Repo.all(query)
  end

  @doc """
  Gets a user's reaction on a post.
  """
  def get_user_reaction(user_id, post_id, emoji) do
    Repo.get_by(Reaction, user_id: user_id, post_id: post_id, emoji: emoji)
  end

  @doc """
  Gets a user's reaction on a message.
  """
  def get_user_reaction_on_message(user_id, message_id, emoji) do
    Repo.get_by(Reaction, user_id: user_id, message_id: message_id, emoji: emoji)
  end

  @doc """
  Adds a reaction to a post.
  """
  def add_reaction(user_id, post_id, emoji) when is_integer(post_id) do
    case get_user_reaction(user_id, post_id, emoji) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{user_id: user_id, post_id: post_id, emoji: emoji})
        |> Repo.insert()
      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Adds a reaction to a message.
  """
  def add_reaction_to_message(user_id, message_id, emoji) when is_integer(message_id) do
    case get_user_reaction_on_message(user_id, message_id, emoji) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{user_id: user_id, message_id: message_id, emoji: emoji})
        |> Repo.insert()
      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Removes a reaction from a post.
  """
  def remove_reaction(user_id, post_id, emoji) when is_integer(post_id) do
    case get_user_reaction(user_id, post_id, emoji) do
      nil -> {:error, :not_found}
      reaction -> Repo.delete(reaction)
    end
  end

  @doc """
  Removes a reaction from a message.
  """
  def remove_reaction_from_message(user_id, message_id, emoji) when is_integer(message_id) do
    case get_user_reaction_on_message(user_id, message_id, emoji) do
      nil -> {:error, :not_found}
      reaction -> Repo.delete(reaction)
    end
  end

  @doc """
  Gets reaction counts grouped by emoji for a post.
  """
  def get_reaction_counts_for_post(post_id) do
    query = from r in Reaction,
      where: r.post_id == ^post_id,
      group_by: r.emoji,
      select: {r.emoji, count(r.id)}
    Repo.all(query) |> Map.new()
  end

  @doc """
  Gets reaction counts grouped by emoji for a message.
  """
  def get_reaction_counts_for_message(message_id) do
    query = from r in Reaction,
      where: r.message_id == ^message_id,
      group_by: r.emoji,
      select: {r.emoji, count(r.id)}
    Repo.all(query) |> Map.new()
  end
end