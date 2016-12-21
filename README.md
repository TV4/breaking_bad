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

## Configuration

+ `CIRCUIT_BREAKER_LOG_INTERVAL`           Interval between circuit breaker debug logging. Example: `10000`
