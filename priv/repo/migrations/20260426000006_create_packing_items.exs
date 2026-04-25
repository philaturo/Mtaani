defmodule Mtaani.Repo.Migrations.CreatePackingItems do
  use Ecto.Migration

  def change do
    create table(:packing_items, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :category, :string, default: "general" # clothing, gear, documents, health, electronics
      add :is_checked, :boolean, default: false
      add :is_ai_suggested, :boolean, default: false
      add :order_index, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:packing_items, [:trip_id])
    create index(:packing_items, [:category])
    create index(:packing_items, [:is_checked])
  end
end
