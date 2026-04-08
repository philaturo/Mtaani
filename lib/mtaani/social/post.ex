defmodule Mtaani.Social.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
  field :content, :string
  field :likes_count, :integer, default: 0
  field :reposts_count, :integer, default: 0
  field :comments_count, :integer, default: 0
  field :bookmarks_count, :integer, default: 0
  belongs_to :user, Mtaani.Accounts.User
  timestamps()
end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :user_id])
    |> validate_required([:content, :user_id])
  end
end