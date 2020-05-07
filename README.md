# Breaking Bad

Breaking Bad is a circuit breaker that monitors processes for timeouts.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `breaking_bad` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:breaking_bad, "~> 0.1.0"}]
    end
    ```

  2. Ensure `breaking_bad` is started before your application:

    ```elixir
    def application do
      [applications: [:breaking_bad]]
    end
    ```

## ENV Configuration

+ `CIRCUIT_BREAKER_LOG_INTERVAL`           Interval between circuit breaker debug logging. Example: `10000`

## App Configuration

In your `config/config.exs`

```
config :breaking_bad,
  circuits: [%{name: :test, threshold: 2, threshold_ms: 100, reset_ms: 100}]
```

Where
  `name` is the name of the circuit
  `threshold` is the number of failures when the circuit breaker should open
  `threshold_ms` time frame where an error counts towards the threshold
  `reset_ms` time to reset circuit after failure
  `interval_disabled` disable periodic truncation of failures

Examples with the values above:
* A circuit will not fail if 2 errors happen 101 ms from each other since 101 ms is a larger timeframe than our 100 ms threshold.
* A circuit will fail if 2 errors happen 100 ms from each other. It will then reset after an additional 100 ms.
