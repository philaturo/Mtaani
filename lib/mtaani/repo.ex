defmodule Mtaani.Repo do
  use Ecto.Repo,
    otp_app: :mtaani,
    adapter: Ecto.Adapters.Postgres

  # Use Geo.PostGIS type module
  # @type_module Geo.PostGIS
end
