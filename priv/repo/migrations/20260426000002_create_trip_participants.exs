defmodule Mtaani.Repo.Migrations.CreateTripParticipants do
  use Ecto.Migration

  def change do
    create table(:trip_participants, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "member" # admin, member
      add :committed_amount, :integer, default: 0
      add :payment_status, :string, default: "pending" # pending, paid, refunded
      add :has_voted, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trip_participants, [:trip_id, :user_id])
    create index(:trip_participants, [:user_id])
    create index(:trip_participants, [:payment_status])
  end
end
