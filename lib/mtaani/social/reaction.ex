defmodule Mtaani.Social.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  @reaction_types ["❤️", "👍", "😂", "😮", "😢", "🙏"]

  schema "reactions" do
    field :emoji, :string
    belongs_to :user, Mtaani.Accounts.User
    belongs_to :post, Mtaani.Social.Post
    belongs_to :message, Mtaani.Chat.Message

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :user_id, :post_id, :message_id])
    |> validate_required([:emoji, :user_id])
    |> validate_inclusion(:emoji, @reaction_types)
    |> validate_at_least_one_content()
  end

  defp validate_at_least_one_content(changeset) do
    if get_field(changeset, :post_id) or get_field(changeset, :message_id) do
      changeset
    else
      add_error(changeset, :base, "Must react to either a post or a message")
    end
  end
end