defmodule BreakingBad.CircuitBreaker do
  use GenServer
  require Logger

  defstruct name: nil, state: :ok, failure_timestamps: [], threshold: nil, threshold_ms: nil, reset_ms: nil, monitored_refs: [], listeners: []

  def reinit(circuit_name) do
    GenServer.call(circuit_name, :reinit)
  end

  def subscribe(circuit_name) do
    GenServer.call(circuit_name, :subscribe)
  end

  def unsubscribe(circuit_name) do
    GenServer.call(circuit_name, :unsubscribe)
  end

  defp notify(circuit_name, event) do
    GenServer.cast(circuit_name, {:notify, event})
  end

  def state(circuit_name) do
    GenServer.call(circuit_name, :state)
  end

  def melt(circuit_name) do
    GenServer.cast(circuit_name, :melt)
  end

  def ask(circuit_name) do
    GenServer.call(circuit_name, :ask)
  end

  def reset(circuit_name) do
    send(circuit_name, :reset)
  end

  def monitor(pid, circuit_name) do
    GenServer.cast(circuit_name, {:monitor, pid})
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  ## GenServer callbacks

  def init(config) do
    if Mix.env != :test do
      :timer.send_interval(Application.get_env(:breaking_bad, :circuit_breaker_interval, 1000), config.name, :interval)
    end
    {:ok, struct(__MODULE__, config)}
  end

  def handle_call(:state, _pid, circuit_breaker) do
    state = circuit_breaker
      |> Map.from_struct
      |> Map.delete(:listeners)
    {:reply, state, circuit_breaker}
  end
  def handle_call(:ask, _pid, circuit_breaker) do
    {:reply, circuit_breaker.state, circuit_breaker}
  end
  def handle_call(:subscribe, {caller, _ref}, circuit_breaker) do
    {:reply, :ok, Map.put(circuit_breaker, :listeners, [caller | circuit_breaker.listeners])}
  end
  def handle_call(:unsubscribe, {caller, _ref}, circuit_breaker) do
    {:reply, :ok, Map.put(circuit_breaker, :listeners, List.delete(circuit_breaker.listeners, caller))}
  end
  def handle_call(:reinit, _pid, circuit_breaker) do
    {:reply, :ok, Map.merge(circuit_breaker, %{state: :ok, failure_timestamps: []})}
  end

  # Do not add failure timestamp when already blown?
  def handle_cast(:melt, circuit_breaker = %__MODULE__{state: :blown}) do
    notify(circuit_breaker.name, :melt)
    {:noreply, circuit_breaker}
  end
  def handle_cast(:melt, circuit_breaker = %__MODULE__{state: :ok}) do
    notify(circuit_breaker.name, :melt)
    circuit_breaker = case do_melt(circuit_breaker) do
      circuit_breaker = %__MODULE__{state: :blown, reset_ms: reset_ms} ->
        Process.send_after(circuit_breaker.name, :reset, reset_ms)
        Enum.each(circuit_breaker.monitored_refs, fn(ref) ->
          Process.demonitor(ref, [:flush])
        end)

        notify(circuit_breaker.name, :blown)
        Map.put(circuit_breaker, :monitored_refs, [])
      circuit_breaker = %__MODULE__{state: :ok} -> circuit_breaker
    end

    {:noreply, circuit_breaker}
  end
  def handle_cast({:monitor, pid}, circuit_breaker) do
    ref = Process.monitor(pid)
    notify(circuit_breaker.name, :monitor)
    {:noreply, Map.put(circuit_breaker, :monitored_refs, [ref | circuit_breaker.monitored_refs])}
  end
  def handle_cast({:notify, event}, circuit_breaker) do
    Logger.debug(inspect({event, circuit_breaker.name}))
    circuit_breaker.listeners
    |> Enum.each(fn(pid) ->
      send(pid, {event, circuit_breaker.name})
    end)

    {:noreply, circuit_breaker}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, circuit_breaker) do
    if reason == :killed do
      melt(circuit_breaker.name)
    end
    notify(circuit_breaker.name, :demonitor)
    {:noreply, Map.put(circuit_breaker, :monitored_refs, List.delete(circuit_breaker.monitored_refs, ref))}
  end
  def handle_info(:reset, circuit_breaker) do
    notify(circuit_breaker.name, :reset)
    {:noreply, Map.put(circuit_breaker, :state, :ok)}
  end
  def handle_info(:interval, circuit_breaker) do
    circuit_breaker = truncate_failure_timestamps(circuit_breaker)
    notify(circuit_breaker.name, {:interval, circuit_breaker})
    {:noreply, circuit_breaker}
  end

  defp truncate_failure_timestamps(circuit_breaker) do
    failure_timestamps = circuit_breaker.failure_timestamps
    |> Enum.filter(fn(failure_timestamp) ->
      (System.monotonic_time(:milliseconds) - failure_timestamp) < circuit_breaker.threshold_ms
    end)
    Map.put(circuit_breaker, :failure_timestamps, failure_timestamps)
  end

  defp do_melt(circuit_breaker) do
    failure_timestamps = [System.monotonic_time(:milliseconds) | circuit_breaker.failure_timestamps]
      |> Enum.take(circuit_breaker.threshold)
    circuit_breaker = Map.put(circuit_breaker, :failure_timestamps, failure_timestamps)

    if length(failure_timestamps) == circuit_breaker.threshold
    && diff(circuit_breaker) < circuit_breaker.threshold_ms do
      Map.put(circuit_breaker, :state, :blown)
    else
      circuit_breaker
    end
  end

  def diff(%__MODULE__{failure_timestamps: []}) do
    0
  end
  def diff(%__MODULE__{failure_timestamps: failure_timestamps}) do
    List.first(failure_timestamps) - List.last(failure_timestamps)
  end
end
