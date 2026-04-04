defmodule Mtaani.Social.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :content, :string
    belongs_to :user, Mtaani.Accounts.User
        
    timestamps()  # This already creates inserted_at and updated_at
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:content, :user_id])
    |> validate_required([:content, :user_id])
  end
end