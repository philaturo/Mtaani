defmodule Mtaani.Social do
  @moduledoc """
  The Social context for posts, comments, and likes.
  """

  import Ecto.Query, warn: false
  alias Mtaani.Repo
  alias Mtaani.Social.Post

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
end