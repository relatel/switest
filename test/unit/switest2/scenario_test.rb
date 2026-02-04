# frozen_string_literal: true

require_relative "../../switest2_test_helper"

# Test scenario assertions directly in Minitest context
class Switest2::ScenarioTest < Minitest::Test
  def setup
    @events = Switest2::Events.new
    @connection = Switest2::ESL::MockConnection.new
    @client = Switest2::ESL::Client.new(@connection)
    Switest2::Agent.setup(@client, @events)
  end

  def teardown
    Switest2::Agent.teardown
  end

  # Helper to create a call
  def make_call(to: "71999999", from: "12345")
    Switest2::ESL::Call.new(
      id: "test-uuid-#{rand(10000)}",
      connection: @connection,
      direction: :inbound,
      to: to,
      from: from
    )
  end

  # Test the assertion logic without using Scenario class directly
  # since we can't easily mock the ESL connection in Scenario.setup

  def test_assert_call_success
    agent = Switest2::Agent.listen_for_call
    call = make_call

    @events.emit(:offer, { to: call.to, from: call.from, call: call })

    # Agent should have received the call
    success = agent.wait_for_call(timeout: 1)
    assert success, "Expected agent to receive a call"
    assert_equal call, agent.call
  end

  def test_assert_call_failure
    agent = Switest2::Agent.listen_for_call

    # No call emitted, so wait should timeout
    success = agent.wait_for_call(timeout: 0.5)
    refute success, "Expected agent to not receive a call"
    assert_nil agent.call
  end

  def test_assert_no_call_success
    agent = Switest2::Agent.listen_for_call

    # No call emitted
    sleep 0.2
    refute agent.call?, "Expected agent to not have received a call"
  end

  def test_assert_no_call_failure
    agent = Switest2::Agent.listen_for_call
    call = make_call

    @events.emit(:offer, { to: call.to, from: call.from, call: call })

    # Agent should have the call
    assert agent.call?, "Expected agent to have received a call"
  end

  def test_assert_hungup_success
    call = make_call
    agent = Switest2::Agent.new(call)

    Thread.new {
      sleep 0.2
      call.handle_hangup("NORMAL_CLEARING")
    }

    success = agent.wait_for_end(timeout: 1)
    assert success, "Expected call to be hung up"
    assert agent.ended?
  end

  def test_assert_hungup_failure
    call = make_call
    agent = Switest2::Agent.new(call)

    # Don't hangup, so wait should timeout
    success = agent.wait_for_end(timeout: 0.3)
    refute success, "Expected call to not be hung up yet"
    refute agent.ended?
  end

  def test_assert_not_hungup_success
    call = make_call
    agent = Switest2::Agent.new(call)

    # Call is still alive
    sleep 0.2
    refute agent.ended?, "Expected call to still be active"
  end

  def test_assert_dtmf_success
    call = make_call
    agent = Switest2::Agent.new(call)

    Thread.new {
      sleep 0.1
      call.handle_dtmf("1")
      call.handle_dtmf("2")
      call.handle_dtmf("3")
    }

    received = agent.receive_dtmf(count: 3, timeout: 1)
    assert_equal "123", received
  end

  def test_assert_dtmf_partial_timeout
    call = make_call
    agent = Switest2::Agent.new(call)

    Thread.new {
      sleep 0.1
      call.handle_dtmf("9")
    }

    # Only one digit sent, waiting for 3
    received = agent.receive_dtmf(count: 3, timeout: 0.5)
    assert_equal "9", received  # Should get what was sent before timeout
  end
end
