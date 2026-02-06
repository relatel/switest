# frozen_string_literal: true

# Integration tests for Scenario against real FreeSWITCH
#
# Run with:
#   rake integration

require_relative "../integration_test_helper"

class ScenarioIntegrationTest < Switest2::Scenario

  def test_scenario_setup_connects
    # setup already ran, client should be connected
    assert @client.connection.connected?, "Scenario should connect on setup"
  end

  def test_agent_listen_for_call
    # Set up a listener - should not raise
    agent = Agent.listen_for_call(to: /test/)

    refute agent.call?, "Agent should not have a call yet"
  end

  def test_agent_dial_loopback
    # Use loopback to test dialing without external SIP
    # This creates a call that immediately answers itself
    agent = Agent.dial("loopback/echo/public")

    assert agent.call?, "Agent should have a call after dial"
    assert_instance_of Switest2::ESL::Call, agent.call

    # Wait for the loopback legs to bridge
    agent.wait_for_bridge(timeout: 5)

    # Clean up - wait for hangup to complete
    agent.hangup
  end

  def test_wait_for_call_timeout
    agent = Agent.listen_for_call(to: /nonexistent_pattern_12345/)

    # No call will match, so this should timeout
    result = agent.wait_for_call(timeout: 1)

    refute result, "wait_for_call should return false on timeout"
    refute agent.call?, "Agent should not have a call"
  end
end
