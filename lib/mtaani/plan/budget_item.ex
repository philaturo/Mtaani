defmodule Mtaani.Plan.BudgetItem do
  use Ecto.Schema
  import Ecto.Changeset
  alias Mtaani.Accounts.User
  alias Mtaani.Plan.Trip

  schema "budget_items" do
    field(:category, :string)
    field(:description, :string)
    field(:amount, :integer)
    field(:expense_date, :date)
    field(:receipt_url, :string)
    field(:notes, :string)

    belongs_to(:trip, Trip)
    belongs_to(:paid_by, User, foreign_key: :paid_by_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :trip_id,
      :category,
      :description,
      :amount,
      :paid_by_id,
      :expense_date,
      :receipt_url,
      :notes
    ])
    |> validate_required([:trip_id, :category, :description, :amount, :expense_date])
    |> validate_inclusion(:category, ["accommodation", "activities", "food", "transport", "other"])
    |> validate_number(:amount, greater_than: 0)
  end
end
