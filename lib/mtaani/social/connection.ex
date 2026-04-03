defmodule Mtaani.Social.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "connections" do
    field :status, :string, default: "pending"
    belongs_to :user, Mtaani.Accounts.User
    belongs_to :buddy, Mtaani.Accounts.User
    
    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:user_id, :buddy_id, :status])
    |> validate_required([:user_id, :buddy_id])
    |> validate_inclusion(:status, ["pending", "accepted", "declined"])
    |> unique_constraint(:user_id, name: :connections_user_id_buddy_id_index)
  end
end