defmodule BreakingBad do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    [
      supervisor(BreakingBad.CircuitBreaker.Supervisor, [
        Application.get_env(:breaking_bad, :circuits, [])
      ])
    ]
    |> Supervisor.start_link(strategy: :one_for_one, name: BreakingBad.Supervisor)
  end
end
