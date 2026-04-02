defmodule Mtaani.Chat.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :name, :string
    field :description, :string
    
    belongs_to :creator, Mtaani.Accounts.User, foreign_key: :created_by
    has_many :messages, Mtaani.Chat.Message
    
    timestamps()
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :created_by])
    |> validate_required([:name])
  end
end