# frozen_string_literal: true

# Integration tests for actual call scenarios
#
# Run with:
#   docker compose run --rm test

$LOAD_PATH.unshift("lib")

require "minitest/autorun"
require "switest2"

class CallIntegrationTest < Switest2::Scenario
  def setup
    # Configure before parent setup creates the client
    Switest2.configure do |config|
      config.host = ENV.fetch("FREESWITCH_HOST", "127.0.0.1")
      config.port = ENV.fetch("FREESWITCH_PORT", 8021).to_i
      config.password = ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
    end
    super
  end

  def test_dial_and_hangup
    # Dial a loopback call that parks
    alice = Agent.dial("loopback/park/public")

    assert alice.call?, "Agent should have a call after dial"
    assert alice.call.outbound?, "Call should be outbound"

    # Give it a moment to set up
    sleep 0.5

    # Hangup
    alice.hangup

    # Wait for hangup to complete
    assert alice.wait_for_end(timeout: 15), "Call should end after hangup"
    assert alice.ended?, "Agent should show call as ended"
  end

  def test_dial_and_wait_for_answer
    # Dial loopback which auto-answers (use public context for our dialplan)
    alice = Agent.dial("loopback/echo/public")

    assert alice.call?, "Agent should have a call"

    # Wait for the call to be answered
    answered = alice.wait_for_answer(timeout: 5)
    assert answered, "Call should be answered"
    assert alice.answered?, "Agent should show call as answered"

    # Clean up
    alice.hangup
    alice.wait_for_end(timeout: 15)
  end

  def test_call_state_transitions
    alice = Agent.dial("loopback/echo/public")

    # Initially offered/ringing
    assert alice.call.alive?, "Call should be alive"

    # Wait for answer
    alice.wait_for_answer(timeout: 5)
    assert alice.call.active?, "Call should be active after answer"
    assert alice.call.answered?, "Call should be answered"
    refute alice.call.ended?, "Call should not be ended"

    # Hangup
    alice.hangup
    alice.wait_for_end(timeout: 15)

    assert alice.call.ended?, "Call should be ended"
    refute alice.call.alive?, "Call should not be alive"
    refute alice.call.active?, "Call should not be active"
    # answered? should still be true (it was answered before ending)
    assert alice.call.answered?, "Call should still show as was-answered"
  end

  def test_call_timestamps
    alice = Agent.dial("loopback/echo/public")

    assert alice.start_time, "Call should have start_time"
    assert_instance_of Time, alice.start_time

    alice.wait_for_answer(timeout: 5)
    assert alice.answer_time, "Call should have answer_time after answer"
    assert alice.answer_time >= alice.start_time, "answer_time should be >= start_time"

    alice.hangup
    alice.wait_for_end(timeout: 15)

    assert alice.call.end_time, "Call should have end_time"
    assert alice.call.end_time >= alice.answer_time, "end_time should be >= answer_time"
  end

  def test_call_end_reason
    alice = Agent.dial("loopback/echo/public")
    alice.wait_for_answer(timeout: 5)

    alice.hangup
    alice.wait_for_end(timeout: 15)

    assert alice.end_reason, "Call should have end_reason"
    # Normal hangup typically gives NORMAL_CLEARING
    assert_includes ["NORMAL_CLEARING", "ORIGINATOR_CANCEL"], alice.end_reason
  end

  def test_multiple_sequential_calls
    # First call
    alice = Agent.dial("loopback/echo/public")
    alice.wait_for_answer(timeout: 5)
    alice.hangup
    alice.wait_for_end(timeout: 15)

    assert alice.ended?, "First call should be ended"

    # Second call
    bob = Agent.dial("loopback/echo/public")
    bob.wait_for_answer(timeout: 5)

    assert bob.answered?, "Second call should be answered"
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    bob.hangup
    bob.wait_for_end(timeout: 15)
  end

  def test_receive_dtmf
    # Dial a destination that sends DTMF digits "123"
    alice = Agent.dial("loopback/dtmf_123/public")

    assert alice.call?, "Agent should have a call"

    # Wait for answer
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    # Receive DTMF digits (the dialplan sends "123" after 500ms)
    digits = alice.call.receive_dtmf(count: 3, timeout: 5)

    assert_equal "123", digits, "Should receive DTMF digits 123"

    # Clean up
    alice.hangup
    alice.wait_for_end(timeout: 15)
  end

  def test_receive_dtmf_partial_timeout
    # Dial a destination that sends only "12"
    alice = Agent.dial("loopback/dtmf_12/public")

    alice.wait_for_answer(timeout: 5)

    # Try to receive 5 digits but only 2 will arrive
    digits = alice.call.receive_dtmf(count: 5, timeout: 3)

    assert_equal "12", digits, "Should receive partial DTMF digits"

    alice.hangup
    alice.wait_for_end(timeout: 15)
  end

  def test_inbound_call_via_loopback
    # Set up a listener for inbound calls to "inbound_test"
    # The loopback B-leg will appear as an inbound call
    bob = Agent.listen_for_call(to: /inbound_test/)

    refute bob.call?, "Bob should not have a call yet"

    # Dial loopback - the B-leg goes to dialplan as inbound
    alice = Agent.dial("loopback/inbound_test/public")

    assert alice.call?, "Alice should have outbound call"

    # Bob should receive the inbound call (B-leg)
    assert bob.wait_for_call(timeout: 5), "Bob should receive inbound call"
    assert bob.call?, "Bob should have a call"
    assert bob.call.inbound?, "Bob's call should be inbound"

    # Bob answers
    bob.answer
    sleep 0.5

    # Both should now be connected
    assert alice.wait_for_answer(timeout: 5), "Alice should see answer"
    assert bob.answered?, "Bob should be answered"

    # Cleanup
    alice.hangup
    alice.wait_for_end(timeout: 15)
    bob.wait_for_end(timeout: 15)
  end

  def test_inbound_call_reject
    bob = Agent.listen_for_call(to: /reject_test/)

    alice = Agent.dial("loopback/reject_test/public")

    assert bob.wait_for_call(timeout: 5), "Bob should receive call"

    # Bob rejects the call
    bob.reject(:busy)

    # Both calls should end
    alice.wait_for_end(timeout: 15)
    bob.wait_for_end(timeout: 15)

    assert alice.ended?, "Alice should be ended"
    assert bob.ended?, "Bob should be ended"
  end

  def test_multiple_concurrent_calls
    # Start two calls at once
    alice = Agent.dial("loopback/echo/public")
    bob = Agent.dial("loopback/echo/public")

    # Both should exist
    assert alice.call?, "Alice should have a call"
    assert bob.call?, "Bob should have a call"
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    # Wait for both to answer
    alice.wait_for_answer(timeout: 5)
    bob.wait_for_answer(timeout: 5)

    assert alice.answered?, "Alice should be answered"
    assert bob.answered?, "Bob should be answered"

    # Hangup both
    alice.hangup
    bob.hangup

    alice.wait_for_end(timeout: 15)
    bob.wait_for_end(timeout: 15)

    assert alice.ended?, "Alice should be ended"
    assert bob.ended?, "Bob should be ended"
  end
end
