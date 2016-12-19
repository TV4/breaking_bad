defmodule BreakingBadTest do
  use ExUnit.Case
  import BreakingBad.CircuitBreaker

  setup do
    install(:test, %BreakingBad.CircuitBreaker{name: :test, threshold: 2, threshold_ms: 100, reset_ms: 100})
    subscribe(:test)
    on_exit(fn -> unsubscribe(:test) end)
    :ok
  end

  test "state" do
    assert state(:test) == %{
      name: :test,
      threshold: 2,
      threshold_ms: 100,
      reset_ms: 100,
      failure_timestamps: [],
      state: :ok,
      monitored_refs: []
    }
  end

  describe "ask" do
    test "defaults to ok" do
      assert ask(:test) == :ok
    end

    test "melting under the threshold is ok" do
      melt(:test)
      assert ask(:test) == :ok
    end

    test "melting to the threshold breaks the circuit" do
      melt(:test)
      melt(:test)
      assert ask(:test) == :blown
    end

    test "the circuit resets after the reset time" do
      melt(:test)
      melt(:test)
      assert_receive(:blown)
      assert_receive(:reset, 200)
    end
  end

  test "returns service outage error when circuit is blown" do
    melt(:test)
    melt(:test)
    assert_receive(:blown)
    assert with_circuit_breaker(:test, fn ->
      flunk("The forwarded function should not have been reached if the circuit is blown")
    end) == {:error, %{type: :service_outage, source_error: "System \"test\" outage detected"}}
  end

  test "process killed causes circuit to blow" do
    melt(:test)

    parent = self
    pid = spawn(fn ->
      with_circuit_breaker(:test, fn ->
        send(parent, :timeout)
        :timer.sleep(:infinity) # paused while waiting to be killed
      end)
    end)

    assert_receive(:timeout)
    Process.exit(pid, :kill)

    assert_receive(:blown)
  end

  test "deregister process monitoring after normal process exit" do
    spawn(fn ->
      with_circuit_breaker(:test, fn ->
        nil
      end)
    end)
    assert_receive(:monitor)
    assert_receive(:demonitor)
    assert state(:test).monitored_refs == []
  end

  test "deregister process monitoring when the process has exited before monitoring started" do
    spawn(fn ->
      with_circuit_breaker(:test, fn -> nil end)
    end)
    assert_receive(:monitor)
    assert state(:test).monitored_refs == []
  end

  test "demonitor references when circuit is blown" do
    parent = self
    pid = spawn(fn ->
      with_circuit_breaker(:test, fn ->
        send(parent, :timeout)
        :timer.sleep(:infinity) # paused while waiting to be killed
      end)
    end)
    assert_receive(:timeout)

    melt(:test)
    melt(:test)

    assert_receive(:melt)
    assert_receive(:melt)
    assert_receive(:blown)

    assert state(:test).monitored_refs == []

    Process.exit(pid, :kill)
    refute_receive(:melt)
  end
end
