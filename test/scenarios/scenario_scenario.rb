# frozen_string_literal: true

# Integration tests for Scenario against real FreeSWITCH
#
# Run with:
#   rake scenarios

require_relative "../scenario_helper"

class ScenarioIntegrationTest < Switest::Scenario

  def test_scenario_setup_connects
    assert @client.connected?, "Scenario should connect on setup"
  end

  def test_agent_listen_for_call
    agent = Agent.listen_for_call(to: /test/)

    refute agent.call?, "Agent should not have a call yet"
  end

  def test_agent_dial_loopback
    agent = Agent.dial("loopback/echo/public")

    assert agent.call?, "Agent should have a call after dial"
    assert_instance_of Switest::Call, agent.call

    assert_answered(agent)

    agent.hangup
    assert_hungup(agent)
  end

  def test_wait_for_call_timeout
    agent = Agent.listen_for_call(to: /nonexistent_pattern_12345/)

    result = agent.wait_for_call(timeout: 1)

    refute result, "wait_for_call should return false on timeout"
    refute agent.call?, "Agent should not have a call"
  end
end
