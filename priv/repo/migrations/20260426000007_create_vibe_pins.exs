defmodule Mtaani.Repo.Migrations.CreateVibePins do
  use Ecto.Migration

  def change do
    create table(:vibe_pins, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :image_url, :string
      add :emoji, :string
      add :caption, :string
      add :vibe_tag, :string

      timestamps(type: :utc_datetime)
    end

    create index(:vibe_pins, [:trip_id])
    create index(:vibe_pins, [:user_id])
  end
end
