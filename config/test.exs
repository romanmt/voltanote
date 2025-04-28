import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :voltanote, VoltanoteWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+aSAIkH8JqrCtj7RYfayKa/P7L0MpouggbDTnqTYoPAYxOVs4NcH5zQcTCUiICHY",
  server: false

# Configure your database
config :voltanote, Voltanote.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "voltanote_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# In test we don't send emails
config :voltanote, Voltanote.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
