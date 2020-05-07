defmodule BreakingBad.CircuitBreaker.Supervisor do
  use Supervisor

  def start_link(config \\ []) do
    Supervisor.start_link(__MODULE__, config)
  end

  def init(configs) do
    Enum.map(configs, fn config ->
      worker(BreakingBad.CircuitBreaker, [config], id: config.name)
    end)
    |> Supervisor.init(strategy: :one_for_one)
  end
end
