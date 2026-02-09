# frozen_string_literal: true

# Integration tests for actual call scenarios
#
# Run with:
#   rake integration

require_relative "../integration_helper"

class CallIntegrationTest < Switest::Scenario

  def test_dial_and_hangup
    # Dial a loopback call that parks
    alice = Agent.dial("loopback/park/public")

    assert alice.call?, "Agent should have a call after dial"
    assert alice.call.outbound?, "Call should be outbound"

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
    assert_answered(alice)

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
    assert_call(bob)
    assert bob.call.inbound?, "Bob's call should be inbound"

    # Bob answers (wait for answer to complete)
    bob.answer

    # Both should now be connected
    assert_answered(alice)
    assert bob.answered?, "Bob should be answered"

    # Cleanup
    alice.hangup
    alice.wait_for_end(timeout: 15)
    bob.wait_for_end(timeout: 15)
  end

  def test_inbound_call_reject
    bob = Agent.listen_for_call(to: /reject_test/)

    alice = Agent.dial("loopback/reject_test/public")

    assert_call(bob)

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

    # Wait for both to answer (longer timeout for CI)
    assert_answered(alice, timeout: 10)
    assert_answered(bob, timeout: 10)

    # Hangup both (wait for completion)
    alice.hangup(wait: 15)
    bob.hangup(wait: 15)

    assert alice.ended?, "Alice should be ended"
    assert bob.ended?, "Bob should be ended"
  end

  def test_dial_with_sip_uri_and_display_name
    alice = Agent.dial("loopback/echo/public", from: "gibberish sip:+4512345678@example.com")

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_dial_with_plain_number
    alice = Agent.dial("loopback/echo/public", from: "+4512345678")

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_dial_with_sip_uri_only
    alice = Agent.dial("loopback/echo/public", from: "sip:anonymous@anonymous.invalid")

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_dial_with_tel_uri
    alice = Agent.dial("loopback/echo/public", from: "tel:+4512345678")

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_dial_with_display_name_and_tel_uri
    alice = Agent.dial("loopback/echo/public", from: "John Doe tel:+4512345678")

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_dial_with_quoted_display_name_and_angle_bracketed_sip_uri
    alice = Agent.dial("loopback/echo/public", from: '"Henrik" <sip:1234@example.com>')

    assert alice.call?, "Agent should have a call"
    alice.wait_for_answer(timeout: 5)
    assert alice.answered?, "Call should be answered"

    alice.hangup
    assert alice.ended?, "Call should be ended"
  end

  def test_concurrent_dtmf_calls_receive_correct_digits
    # This tests that DTMF events are correctly routed to the right call
    # when multiple loopback calls are active. Each call should only receive
    # its own DTMF digits, not digits from other calls.
    #
    # This verifies the Other-Leg-Unique-ID fix for loopback call DTMF routing.

    # Start two calls that will send different DTMF patterns
    alice = Agent.dial("loopback/dtmf_111/public")  # Will send "111"
    bob = Agent.dial("loopback/dtmf_222/public")    # Will send "222"

    # Both calls should exist with different IDs
    assert alice.call?, "Alice should have a call"
    assert bob.call?, "Bob should have a call"
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    # Wait for both to answer
    assert_answered(alice)
    assert_answered(bob)

    # Each call should receive its own DTMF digits
    alice_digits = alice.call.receive_dtmf(count: 3, timeout: 5)
    bob_digits = bob.call.receive_dtmf(count: 3, timeout: 5)

    assert_equal "111", alice_digits, "Alice should receive her own DTMF digits (111)"
    assert_equal "222", bob_digits, "Bob should receive his own DTMF digits (222)"

    # Cleanup
    alice.hangup
    bob.hangup
  end

  def test_sequential_dtmf_calls_are_isolated
    # Test that DTMF digits from a previous call don't leak to subsequent calls.
    # This verifies proper call isolation.

    # First call: receive DTMF 123
    alice = Agent.dial("loopback/dtmf_123/public")
    alice.wait_for_answer(timeout: 5)
    digits1 = alice.call.receive_dtmf(count: 3, timeout: 5)
    assert_equal "123", digits1, "First call should receive 123"
    alice.hangup

    # Second call: receive DTMF 456
    bob = Agent.dial("loopback/dtmf_456/public")
    bob.wait_for_answer(timeout: 5)
    digits2 = bob.call.receive_dtmf(count: 3, timeout: 5)
    assert_equal "456", digits2, "Second call should receive 456 (not 123 from previous call)"
    bob.hangup
  end

  def test_hangup_all_ends_multiple_calls
    # Start multiple concurrent calls
    alice = Agent.dial("loopback/echo/public")
    bob = Agent.dial("loopback/echo/public")
    charlie = Agent.dial("loopback/echo/public")

    # Wait for all to answer
    assert_answered(alice)
    assert_answered(bob)
    assert_answered(charlie)

    # All calls should be active
    assert alice.active?, "Alice should be active"
    assert bob.active?, "Bob should be active"
    assert charlie.active?, "Charlie should be active"

    # Hangup all calls at once
    hangup_all

    # All calls should be ended
    assert alice.ended?, "Alice should be ended after hangup_all"
    assert bob.ended?, "Bob should be ended after hangup_all"
    assert charlie.ended?, "Charlie should be ended after hangup_all"

    # All should have NORMAL_CLEARING as the cause (not hupall's cause)
    assert_equal "NORMAL_CLEARING", alice.end_reason, "Alice should have NORMAL_CLEARING"
    assert_equal "NORMAL_CLEARING", bob.end_reason, "Bob should have NORMAL_CLEARING"
    assert_equal "NORMAL_CLEARING", charlie.end_reason, "Charlie should have NORMAL_CLEARING"
  end

  def test_hangup_all_with_custom_cause
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)

    # Hangup with custom cause
    hangup_all(cause: "USER_BUSY")

    assert alice.ended?, "Alice should be ended"
    assert_equal "USER_BUSY", alice.end_reason, "Should use custom hangup cause"
  end

  def test_send_dtmf_detected_by_other_leg
    # Bob listens on dtmf_wait_test — the dialplan runs start_dtmf on the B-leg
    bob = Agent.listen_for_call(to: /dtmf_wait_test/)

    alice = Agent.dial("loopback/dtmf_wait_test/public")

    assert_call(bob)
    bob.answer
    assert_answered(alice)

    # Alice plays DTMF tones — B-leg's start_dtmf should detect them
    assert_dtmf(bob, "789") do
      alice.send_dtmf("789")
    end

    alice.hangup
    bob.wait_for_end(timeout: 5)
  end

  def test_bridge_via_dialplan
    # Listen for the loopback B-leg that will hit the bridge_echo dialplan
    bob = Agent.listen_for_call(to: /bridge_echo/)

    # The B-leg answers and bridges to echo via the dialplan
    alice = Agent.dial("loopback/bridge_echo/public")

    assert_call(bob)
    assert_bridged(bob)

    alice.hangup
    bob.wait_for_end
  end

  def test_hangup_headers_are_available_after_call_ends
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)

    alice.hangup
    assert alice.ended?, "Alice should be ended"

    # Headers from CHANNEL_HANGUP_COMPLETE should be merged
    assert alice.call.headers["Hangup-Cause"], "Should have Hangup-Cause header"
    assert_equal "NORMAL_CLEARING", alice.call.headers["Hangup-Cause"]
  end
end
