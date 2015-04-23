# encoding: utf-8

require "test_helper"

class Switest::ScenarioTest < Minitest::Test
  def setup
    super
    Switest.reset
  end

  def test_assert_call_success
    scenario = Scenario.new(nil)
    call = ::Adhearsion::Call.new
    agent = Agent.listen_for_call

    Timeout.timeout(1) do
      Switest.events.trigger_handler(:inbound_call, call)
      scenario.assert_call(agent)
    end
  end

  def test_assert_called_failure
    scenario = Scenario.new(nil)
    agent = Agent.listen_for_call
    
    Timeout.timeout(2) do
      assert_raises Minitest::Assertion do
        scenario.assert_call(agent, timeout: 1)
      end
    end
  end

  def test_assert_no_call_success
    scenario = Scenario.new(nil)
    call = ::Adhearsion::Call.new
    agent = Agent.listen_for_call

    Timeout.timeout(2) do
      scenario.assert_no_call(agent, timeout: 1)
    end
  end

  def test_assert_no_call_failure
    scenario = Scenario.new(nil)
    call = ::Adhearsion::Call.new
    agent = Agent.listen_for_call

    Switest.events.trigger_handler(:inbound_call, call)

    Timeout.timeout(1) do
      assert_raises Minitest::Assertion do
        scenario.assert_no_call(agent)
      end
    end
  end
end
