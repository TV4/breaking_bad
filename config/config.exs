use Mix.Config

config :breaking_bad,
  circuit_breaker_enabled: (System.get_env("CIRCUIT_BREAKER_ENABLED") || "true") == "true",
  circuit_breaker_log_interval: String.to_integer(System.get_env("CIRCUIT_BREAKER_LOG_INTERVAL") || "10000")

import_config "#{Mix.env}.exs"
