defmodule Mtaani.Groups.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Groups.Group

  schema "group_members" do
    belongs_to(:group, Group, foreign_key: :group_id)
    belongs_to(:user, User, foreign_key: :user_id)

    field(:role, :string, default: "member")
    field(:is_online, :boolean, default: false)
    field(:last_active, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :joined_at, updated_at: :updated_at)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:group_id, :user_id, :role, :is_online, :last_active])
    |> validate_required([:group_id, :user_id])
    |> validate_inclusion(:role, ["admin", "moderator", "member"])
    |> unique_constraint([:group_id, :user_id])
    |> assoc_constraint(:group)
    |> assoc_constraint(:user)
  end

  def join_changeset(member, group_id, user_id) do
    member
    |> changeset(%{group_id: group_id, user_id: user_id, role: "member"})
  end
end
