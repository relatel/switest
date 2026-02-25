# frozen_string_literal: true

# Integration tests for actual call scenarios
#
# Run with:
#   rake scenarios

require_relative "../scenario_helper"

class CallIntegrationTest < Switest::Scenario

  def test_dial_and_hangup
    alice = Agent.dial("loopback/echo/public")

    assert alice.call?, "Agent should have a call after dial"
    assert alice.call.outbound?, "Call should be outbound"

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_and_wait_for_answer
    alice = Agent.dial("loopback/echo/public")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_call_state_transitions
    alice = Agent.dial("loopback/echo/public")

    assert alice.call.alive?, "Call should be alive"

    assert_answered(alice)
    assert alice.call.active?, "Call should be active after answer"
    assert alice.call.answered?, "Call should be answered"
    refute alice.call.ended?, "Call should not be ended"

    alice.hangup
    assert_hungup(alice)

    assert alice.call.ended?, "Call should be ended"
    refute alice.call.alive?, "Call should not be alive"
    refute alice.call.active?, "Call should not be active"
    assert alice.call.answered?, "Call should still show as was-answered"
  end

  def test_call_timestamps
    alice = Agent.dial("loopback/echo/public")

    assert alice.start_time, "Call should have start_time"
    assert_instance_of Time, alice.start_time

    assert_answered(alice)
    assert alice.answer_time, "Call should have answer_time after answer"
    assert alice.answer_time >= alice.start_time, "answer_time should be >= start_time"

    alice.hangup
    assert_hungup(alice)

    assert alice.call.end_time, "Call should have end_time"
    assert alice.call.end_time >= alice.answer_time, "end_time should be >= answer_time"
  end

  def test_call_end_reason
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)

    assert alice.end_reason, "Call should have end_reason"
    assert_includes ["NORMAL_CLEARING", "ORIGINATOR_CANCEL"], alice.end_reason
  end

  def test_multiple_sequential_calls
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)
    alice.hangup
    assert_hungup(alice)

    bob = Agent.dial("loopback/echo/public")
    assert_answered(bob)
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    bob.hangup
    assert_hungup(bob)
  end

  def test_receive_dtmf
    alice = Agent.dial("loopback/dtmf_123/public")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    assert_dtmf(alice, "123")

    alice.hangup
    assert_hungup(alice)
  end

  def test_receive_dtmf_partial_timeout
    alice = Agent.dial("loopback/dtmf_12/public")

    assert_answered(alice)

    # Try to receive 5 digits but only 2 will arrive
    digits = alice.call.receive_dtmf(count: 5, timeout: 3)
    assert_equal "12", digits, "Should receive partial DTMF digits"

    alice.hangup
    assert_hungup(alice)
  end

  def test_inbound_call_via_loopback
    bob = Agent.listen_for_call(to: /inbound_test/)

    refute bob.call?, "Bob should not have a call yet"

    alice = Agent.dial("loopback/inbound_test/public")

    assert alice.call?, "Alice should have outbound call"

    assert_call(bob)
    assert bob.call.inbound?, "Bob's call should be inbound"

    bob.answer
    assert_answered(alice)
    assert_answered(bob)

    alice.hangup
    assert_hungup(alice)
    assert_hungup(bob)
  end

  def test_inbound_call_reject
    bob = Agent.listen_for_call(to: /reject_test/)

    alice = Agent.dial("loopback/reject_test/public")

    assert_call(bob)

    bob.reject(:busy)

    assert_hungup(alice)
    assert_hungup(bob)
  end

  def test_multiple_concurrent_calls
    alice = Agent.dial("loopback/echo/public")
    bob = Agent.dial("loopback/echo/public")

    assert alice.call?, "Alice should have a call"
    assert bob.call?, "Bob should have a call"
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    assert_answered(alice, timeout: 10)
    assert_answered(bob, timeout: 10)

    alice.hangup
    bob.hangup
    assert_hungup(alice)
    assert_hungup(bob)
  end

  def test_dial_with_sip_uri_and_display_name
    alice = Agent.dial("loopback/echo/public", from: "gibberish sip:+4512345678@example.com")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_with_plain_number
    alice = Agent.dial("loopback/echo/public", from: "+4512345678")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_with_sip_uri_only
    alice = Agent.dial("loopback/echo/public", from: "sip:anonymous@anonymous.invalid")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_with_tel_uri
    alice = Agent.dial("loopback/echo/public", from: "tel:+4512345678")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_with_display_name_and_tel_uri
    alice = Agent.dial("loopback/echo/public", from: "John Doe tel:+4512345678")

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_dial_with_quoted_display_name_and_angle_bracketed_sip_uri
    alice = Agent.dial("loopback/echo/public", from: '"Henrik" <sip:1234@example.com>')

    assert alice.call?, "Agent should have a call"
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)
  end

  def test_concurrent_dtmf_calls_receive_correct_digits
    alice = Agent.dial("loopback/dtmf_111/public")
    bob = Agent.dial("loopback/dtmf_222/public")

    assert alice.call?, "Alice should have a call"
    assert bob.call?, "Bob should have a call"
    refute_equal alice.call.id, bob.call.id, "Calls should have different IDs"

    assert_answered(alice)
    assert_answered(bob)

    assert_dtmf(alice, "111")
    assert_dtmf(bob, "222")

    alice.hangup
    bob.hangup
  end

  def test_sequential_dtmf_calls_are_isolated
    alice = Agent.dial("loopback/dtmf_123/public")
    assert_answered(alice)
    assert_dtmf(alice, "123")
    alice.hangup

    bob = Agent.dial("loopback/dtmf_456/public")
    assert_answered(bob)
    assert_dtmf(bob, "456")
    bob.hangup
  end

  def test_hangup_all_ends_multiple_calls
    alice = Agent.dial("loopback/echo/public")
    bob = Agent.dial("loopback/echo/public")
    charlie = Agent.dial("loopback/echo/public")

    assert_answered(alice)
    assert_answered(bob)
    assert_answered(charlie)

    assert alice.active?, "Alice should be active"
    assert bob.active?, "Bob should be active"
    assert charlie.active?, "Charlie should be active"

    hangup_all

    assert alice.ended?, "Alice should be ended after hangup_all"
    assert bob.ended?, "Bob should be ended after hangup_all"
    assert charlie.ended?, "Charlie should be ended after hangup_all"

    assert_equal "NORMAL_CLEARING", alice.end_reason
    assert_equal "NORMAL_CLEARING", bob.end_reason
    assert_equal "NORMAL_CLEARING", charlie.end_reason
  end

  def test_hangup_all_with_custom_cause
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)

    hangup_all(cause: "USER_BUSY")

    assert alice.ended?, "Alice should be ended"
    assert_equal "USER_BUSY", alice.end_reason
  end

  def test_send_dtmf_detected_by_other_leg
    bob = Agent.listen_for_call(to: /dtmf_wait_test/)

    alice = Agent.dial("loopback/dtmf_wait_test/public")

    assert_call(bob)
    bob.answer
    assert_answered(alice)

    assert_dtmf(bob, "789") do
      alice.send_dtmf("789")
    end

    alice.hangup
    assert_hungup(bob)
  end

  def test_inbound_answer_connects_loopback
    bob = Agent.listen_for_call(to: /bridge_echo/)

    alice = Agent.dial("loopback/bridge_echo/public")

    assert_call(bob)

    bob.answer
    assert_answered(alice)
    assert_answered(bob)

    alice.hangup
    assert_hungup(bob)
  end

  def test_hangup_headers_are_available_after_call_ends
    alice = Agent.dial("loopback/echo/public")
    assert_answered(alice)

    alice.hangup
    assert_hungup(alice)

    assert alice.call.headers[:hangup_cause], "Should have :hangup_cause header"
    assert_equal "NORMAL_CLEARING", alice.call.headers[:hangup_cause]
  end
end
