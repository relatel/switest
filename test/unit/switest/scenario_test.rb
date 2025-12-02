# frozen_string_literal: true

require "test_helper"

class Switest::ScenarioTest < Minitest::Test
  def setup
    super
    Switest.reset
  end

  def test_assert_call_success
    scenario = Scenario.new(nil)
    call = create_mock_call
    agent = Agent.listen_for_call

    Timeout.timeout(1) do
      Switest.events.trigger(:inbound_call, call)
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
    agent = Agent.listen_for_call

    Timeout.timeout(2) do
      scenario.assert_no_call(agent, timeout: 1)
    end
  end

  def test_assert_no_call_failure
    scenario = Scenario.new(nil)
    call = create_mock_call
    agent = Agent.listen_for_call

    Switest.events.trigger(:inbound_call, call)

    Timeout.timeout(1) do
      assert_raises Minitest::Assertion do
        scenario.assert_no_call(agent)
      end
    end
  end

  def test_assert_hungup
    scenario = Scenario.new(nil)
    agent = Agent.new
    agent.call = create_mock_call
    agent.call.simulate_answer
    agent.call.simulate_end(:hangup)

    scenario.assert_hungup(agent)
  end

  def test_assert_answered
    scenario = Scenario.new(nil)
    agent = Agent.new
    agent.call = create_mock_call
    agent.call.simulate_answer

    scenario.assert_answered(agent)
  end

  private

  def create_mock_call(to: nil, from: nil, headers: {})
    mock_client = Rayo::MockClient.new
    Rayo::MockCall.new(mock_client, to: to, from: from, headers: headers)
  end
end
