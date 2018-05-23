defmodule BreakingBadTest do
  use ExUnit.Case
  import BreakingBad.CircuitBreaker

  setup do
    reinit(:test)
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
      assert_receive({:blown, :test})
      assert_receive({:reset, :test}, 200)
    end
  end

  test "process killed causes circuit to blow" do
    melt(:test)

    pid =
      spawn(fn ->
        monitor(self(), :test)
        # paused while waiting to be killed
        :timer.sleep(:infinity)
      end)

    assert_receive({:monitor, :test})
    Process.exit(pid, :kill)

    assert_receive({:blown, :test})
  end

  test "deregister process monitoring after normal process exit" do
    pid =
      spawn(fn ->
        monitor(self(), :test)

        receive do
          :exit -> nil
        end
      end)

    assert_receive({:monitor, :test})
    send(pid, :exit)
    assert_receive({:demonitor, :test})
    assert state(:test).monitored_refs == []
  end

  test "deregister process monitoring when the process has exited before monitoring started" do
    pid = spawn(fn -> nil end)
    monitor(pid, :test)
    assert_receive({:monitor, :test})
    assert_receive({:demonitor, :test})
    assert state(:test).monitored_refs == []
  end

  test "demonitor references when circuit is blown" do
    pid =
      spawn(fn ->
        monitor(self(), :test)
        # paused while waiting to be killed
        :timer.sleep(:infinity)
      end)

    assert_receive({:monitor, :test})
    assert length(state(:test).monitored_refs) == 1

    melt(:test)
    melt(:test)

    assert_receive({:melt, :test})
    assert_receive({:melt, :test})
    assert_receive({:blown, :test})

    assert state(:test).monitored_refs == []

    Process.exit(pid, :kill)
    refute_receive({:melt, :test})
  end
end
