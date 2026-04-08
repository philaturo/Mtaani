# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# Load environment variables from .env file if it exists
if File.exists?(".env") do
  File.stream!(".env")
  |> Enum.each(fn line ->
    line = String.trim(line)
    if line != "" and not String.starts_with?(line, "#") do
      case String.split(line, "=", parts: 2) do
        [key, value] -> System.put_env(key, value)
        _ -> :ok
      end
    end
  end)
end

# General application configuration
import Config

config :mtaani,
  ecto_repos: [Mtaani.Repo],
  generators: [timestamp_type: :utc_datetime]

# Geo configuration (ADD THIS BLOCK)
# config :geo,
  # json_library: Jason,
 # postgis_extension: true

# Ecto Repo with PostGIS types
# config :mtaani, Mtaani.Repo,
 # types: Geo.PostGIS.Type

# Configure the endpoint
config :mtaani, MtaaniWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MtaaniWeb.ErrorHTML, json: MtaaniWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mtaani.PubSub,
  live_view: [signing_salt: "eZHIg6gA"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :mtaani, Mtaani.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mtaani: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  mtaani: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Groq API Key (loaded from .env or environment variable)
config :mtaani, :groq_api_key, System.get_env("GROQ_API_KEY")

# ==================== REDIS CONFIGURATION ====================
# Redis Configuration for read receipts and caching
config :mtaani, :redis,
  host: System.get_env("REDIS_HOST") || "localhost",
  port: String.to_integer(System.get_env("REDIS_PORT") || "6379")

# ==================== END REDIS CONFIGURATION ====================

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"