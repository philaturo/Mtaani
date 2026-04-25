defmodule Mtaani.Repo.Migrations.CreateBudgetItems do
  use Ecto.Migration

  def change do
    create table(:budget_items, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :category, :string, null: false # accommodation, activities, food, transport, other
      add :description, :string, null: false
      add :amount, :integer, null: false
      add :paid_by_id, references(:users, on_delete: :nothing)
      add :expense_date, :date, null: false
      add :receipt_url, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:budget_items, [:trip_id])
    create index(:budget_items, [:category])
    create index(:budget_items, [:paid_by_id])
    create index(:budget_items, [:expense_date])
  end
end
