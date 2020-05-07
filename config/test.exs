use Mix.Config

config :breaking_bad,
  circuits: [
    %{name: :test, threshold: 2, threshold_ms: 100, reset_ms: 100, interval_disabled: true}
  ]

# Print only warnings and errors during test
config :logger, level: :warn
