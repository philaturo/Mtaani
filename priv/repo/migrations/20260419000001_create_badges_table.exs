defmodule Mtaani.Repo.Migrations.CreateBadgesTable do
  use Ecto.Migration

  def change do
    create table(:badges, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :type, :string, null: false
      add :name, :string, null: false
      add :icon, :string, null: false
      add :description, :string
      add :threshold_field, :string, null: false
      add :threshold_value, :integer, null: false
      add :category, :string, default: "travel"
      add :is_active, :boolean, default: true
      timestamps()
    end

    create unique_index(:badges, [:type])
    create index(:badges, [:threshold_field, :threshold_value])

    # Insert default badges
    execute("""
      INSERT INTO badges (type, name, icon, description, threshold_field, threshold_value, category, inserted_at, updated_at)
      VALUES
        ('safari_veteran', 'Safari veteran', '🦁', '5+ game drives', 'trips_count', 5, 'travel', NOW(), NOW()),
        ('summit_chaser', 'Summit chaser', '🥾', 'Climbed Mt. Kenya or peaks', 'peaks_climbed', 1, 'travel', NOW(), NOW()),
        ('coastal_explorer', 'Coastal explorer', '🌊', '3+ coast trips', 'coast_visits', 3, 'travel', NOW(), NOW()),
        ('group_organiser', 'Group organiser', '🤝', 'Led 4+ group trips', 'tours_led', 4, 'guide', NOW(), NOW()),
        ('kenya_explorer', 'Kenya explorer', '🗺️', 'Visited 30+ counties', 'counties_count', 30, 'travel', NOW(), NOW())
    """)
  end
end
