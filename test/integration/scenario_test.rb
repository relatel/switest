# frozen_string_literal: true

# Integration tests for Scenario against real FreeSWITCH
#
# Requires FreeSWITCH running:
#   docker compose up -d
#
# Run with:
#   docker compose run --rm test

$LOAD_PATH.unshift("lib")

require "minitest/autorun"
require "switest2"

class ScenarioIntegrationTest < Switest2::Scenario
  def setup
    # Configure before parent setup creates the client
    Switest2.configure do |config|
      config.host = ENV.fetch("FREESWITCH_HOST", "127.0.0.1")
      config.port = ENV.fetch("FREESWITCH_PORT", 8021).to_i
      config.password = ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
    end
    super
  end

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

    # Wait a moment for the call to be set up
    sleep 0.5

    # Clean up
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
