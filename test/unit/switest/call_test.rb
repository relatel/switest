# frozen_string_literal: true

require_relative "../../test_helper"

class Switest::CallTest < Minitest::Test
  def setup
    @session = Switest::MockSession.new
  end

  def make_call(direction: :inbound, id: "test-uuid")
    Switest::Call.new(
      id: id,
      direction: direction,
      session: @session
    )
  end

  def make_event(event_name, content = {})
    content = { event_name: event_name }.merge(content)
    Struct.new(:headers, :content, :event) do
      def event?
        true
      end
    end.new({}, content, event_name)
  end

  def test_initial_state_is_offered
    call = make_call

    assert_equal :offered, call.state
    assert call.alive?
    refute call.active?
    refute call.answered?
    refute call.ended?
  end

  def test_handle_answer_transitions_to_ringing
    call = make_call

    call.handle_answer

    assert_equal :ringing, call.state
    assert call.alive?
    refute call.active?
    refute call.answered?
    refute call.ended?
    assert_instance_of Time, call.answer_time
  end

  def test_handle_hangup_transitions_to_ended
    call = make_call

    call.handle_hangup("NORMAL_CLEARING")

    assert_equal :ended, call.state
    refute call.alive?
    refute call.active?
    assert call.ended?
    assert_equal "NORMAL_CLEARING", call.end_reason
    assert_instance_of Time, call.end_time
  end

  def test_handle_hangup_merges_headers
    call = make_call

    call.handle_hangup("NORMAL_CLEARING", {
      variable_billsec: "120",
      variable_duration: "125"
    })

    assert_equal "120", call.headers[:variable_billsec]
    assert_equal "125", call.headers[:variable_duration]
  end

  def test_answered_false_after_hangup
    call = make_call

    call.handle_answer
    call.handle_callstate("ACTIVE")
    call.handle_hangup("NORMAL_CLEARING")

    refute call.answered?, "answered? should be false after hangup"
    assert call.ended?
    assert_instance_of Time, call.answer_time, "answer_time should still be set"
  end

  def test_on_answer_callback
    call = make_call

    callback_called = false
    call.on_answer { callback_called = true }
    call.handle_answer
    call.handle_callstate("ACTIVE")

    assert callback_called
  end

  def test_on_end_callback
    call = make_call

    callback_called = false
    call.on_end { callback_called = true }
    call.handle_hangup("NORMAL_CLEARING")

    assert callback_called
  end

  def test_wait_for_answer_returns_true_on_active
    call = make_call

    Async do
      sleep 0.1
      call.handle_answer
      sleep 0.1
      call.handle_callstate("ACTIVE")
    end

    result = call.wait_for_answer(timeout: 1)
    assert result
  end

  def test_wait_for_answer_returns_false_on_timeout
    call = make_call

    result = call.wait_for_answer(timeout: 0.2)
    refute result
  end

  def test_wait_for_end_returns_true_on_hangup
    call = make_call

    Async do
      sleep 0.2
      call.handle_hangup("NORMAL_CLEARING")
    end

    result = call.wait_for_end(timeout: 1)
    assert result
  end

  def test_handle_callstate_active_transitions_to_answered
    call = make_call

    call.handle_answer
    assert_equal :ringing, call.state
    refute call.answered?

    call.handle_callstate("ACTIVE")
    assert_equal :answered, call.state
    assert call.answered?
    assert call.active?
  end

  def test_handle_callstate_ignored_after_hangup
    call = make_call

    call.handle_hangup("NORMAL_CLEARING")
    call.handle_callstate("ACTIVE")

    refute call.answered?, "Should not be answered after hangup"
  end

  def test_handle_callstate_ignores_non_active
    call = make_call

    call.handle_answer
    call.handle_callstate("RINGING")

    assert_equal :ringing, call.state
    refute call.answered?
  end

  def test_wait_for_answer_waits_for_active
    call = make_call

    Async do
      sleep 0.1
      call.handle_answer
      sleep 0.1
      call.handle_callstate("ACTIVE")
    end

    result = call.wait_for_answer(timeout: 1)
    assert result
    assert call.answered?
  end

  def test_dtmf_buffering
    call = make_call

    call.handle_dtmf("1")
    call.handle_dtmf("2")
    call.handle_dtmf("3")

    digits = call.receive_dtmf(count: 3, timeout: 1)
    assert_equal "123", digits
  end

  def test_flush_dtmf_clears_buffer
    call = make_call

    call.handle_dtmf("1")
    call.handle_dtmf("2")
    call.flush_dtmf

    call.handle_dtmf("3")
    digits = call.receive_dtmf(count: 1, timeout: 1)
    assert_equal "3", digits
  end

  def test_dtmf_timeout
    call = make_call

    call.handle_dtmf("1")

    digits = call.receive_dtmf(count: 3, timeout: 0.2)
    assert_equal "1", digits
  end

  def test_inbound_outbound_direction
    inbound = make_call(direction: :inbound)
    outbound = make_call(direction: :outbound)

    assert inbound.inbound?
    refute inbound.outbound?
    refute outbound.inbound?
    assert outbound.outbound?
  end

  def test_answer_only_works_for_inbound_offered
    inbound = make_call(direction: :inbound)
    outbound = make_call(direction: :outbound)

    inbound.answer(wait: false)
    outbound.answer(wait: false)

    # Only inbound should have sent the answer command
    answer_commands = @session.commands_sent.select { |c| c.include?("execute-app-name: answer") }
    assert_equal 1, answer_commands.length
  end

  def test_answer_sends_sendmsg_execute
    call = make_call(direction: :inbound)

    call.answer(wait: false)

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/call-command: execute/, command)
    assert_match(/execute-app-name: answer/, command)
  end

  def test_hangup_sends_sendmsg_hangup
    call = make_call(direction: :outbound)

    call.hangup("USER_BUSY", wait: false)

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/call-command: hangup/, command)
    assert_match(/hangup-cause: USER_BUSY/, command)
  end

  def test_hangup_defaults_to_normal_clearing
    call = make_call(direction: :outbound)

    call.hangup(wait: false)

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/hangup-cause: NORMAL_CLEARING/, command)
  end

  def test_reject_busy_uses_user_busy_cause
    call = make_call(direction: :inbound)

    call.reject(:busy, wait: false)

    command = @session.commands_sent.last
    assert_match(/hangup-cause: USER_BUSY/, command)
  end

  def test_reject_decline_uses_call_rejected_cause
    call = make_call(direction: :inbound)

    call.reject(:decline, wait: false)

    command = @session.commands_sent.last
    assert_match(/hangup-cause: CALL_REJECTED/, command)
  end

  def test_send_dtmf_defaults_to_wait_true
    call = make_call(direction: :outbound)

    call.send_dtmf("123")

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/execute-app-name: playback/, command)
    assert_match(%r{tone_stream://d=200;w=250;123}, command)
    assert_match(/event-lock: true/, command)
  end

  def test_send_dtmf_with_wait_false_no_event_lock
    call = make_call(direction: :outbound)

    call.send_dtmf("123", wait: false)

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/execute-app-name: playback/, command)
    refute_match(/event-lock/, command)
  end

  def test_play_audio_defaults_to_wait_true
    call = make_call(direction: :outbound)

    call.play_audio("/tmp/test.wav")

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/execute-app-name: playback/, command)
    assert_match(%r{execute-app-arg: /tmp/test.wav}, command)
    assert_match(/event-lock: true/, command)
  end

  def test_play_audio_with_wait_false_no_event_lock
    call = make_call(direction: :outbound)

    call.play_audio("/tmp/test.wav", wait: false)

    command = @session.commands_sent.last
    assert_match(/sendmsg test-uuid/, command)
    assert_match(/execute-app-name: playback/, command)
    refute_match(/event-lock/, command)
  end

  def test_handle_event_dispatches_answer_and_callstate
    call = make_call(direction: :outbound)

    call.handle_event(make_event("CHANNEL_ANSWER", unique_id: "test-uuid"))
    assert_equal :ringing, call.state

    call.handle_event(make_event("CHANNEL_CALLSTATE", unique_id: "test-uuid", channel_call_state: "ACTIVE"))
    assert call.answered?
  end

  def test_handle_event_dispatches_dtmf
    call = make_call(direction: :outbound)
    event = make_event("DTMF", unique_id: "test-uuid", dtmf_digit: "5")

    call.handle_event(event)

    digits = call.receive_dtmf(count: 1, timeout: 0.1)
    assert_equal "5", digits
  end

  def test_handle_event_dispatches_hangup
    call = make_call(direction: :outbound)
    event = make_event("CHANNEL_HANGUP_COMPLETE", unique_id: "test-uuid", hangup_cause: "NORMAL_CLEARING")

    call.handle_event(event)

    assert call.ended?
    assert_equal "NORMAL_CLEARING", call.end_reason
  end
end
