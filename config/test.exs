use Mix.Config

config :gen_poker, :deck, Mocks.StackedDeck

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gen_poker, GenPoker.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :gen_poker, GenPoker.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "gen_poker_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
