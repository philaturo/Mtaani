defmodule Mtaani.Repo.Migrations.CreateGroupChannels do
  use Ecto.Migration

  def change do
    create table(:group_channels) do
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :name, :string, size: 100, null: false
      add :description, :text
      add :channel_order, :integer, default: 0

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create unique_index(:group_channels, [:group_id, :name])
    create index(:group_channels, [:group_id])
    create index(:group_channels, [:channel_order])
  end
end
