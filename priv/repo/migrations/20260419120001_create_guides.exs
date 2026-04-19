defmodule Mtaani.Repo.Migrations.CreateGuides do
  use Ecto.Migration

  def change do
    create table(:guides) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :bio, :text
      add :hourly_rate, :decimal, precision: 10, scale: 2
      add :languages, {:array, :string}, default: []
      add :years_experience, :integer, default: 0
      add :total_tours, :integer, default: 0
      add :rating, :decimal, precision: 3, scale: 2, default: 0.0
      add :reviews_count, :integer, default: 0
      add :availability_status, :string, default: "offline"
      add :verification_status, :string, default: "pending"
      add :verified_at, :utc_datetime

      timestamps()
    end

    create index(:guides, [:user_id])
    create index(:guides, [:availability_status])
    create index(:guides, [:verification_status])
  end
end
