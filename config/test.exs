use Mix.Config

config :breaking_bad,
  circuit_breaker: [%{name: :test, threshold: 2, threshold_ms: 100, reset_ms: 100}]

# Print only warnings and errors during test
config :logger, level: :warn
