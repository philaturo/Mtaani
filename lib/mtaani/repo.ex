defmodule Mtaani.Repo do
  use Ecto.Repo,
    otp_app: :mtaani,
    adapter: Ecto.Adapters.Postgres
end