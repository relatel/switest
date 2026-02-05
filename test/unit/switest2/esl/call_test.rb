# frozen_string_literal: true

require_relative "../../../switest2_test_helper"

class Switest2::ESL::CallTest < Minitest::Test
  def setup
    @connection = Switest2::ESL::MockConnection.new
  end

  def test_initial_state_is_offered
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    assert_equal :offered, call.state
    assert call.alive?
    refute call.active?
    refute call.answered?
    refute call.ended?
  end

  def test_handle_answer_transitions_to_answered
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_answer

    assert_equal :answered, call.state
    assert call.alive?
    assert call.active?
    assert call.answered?
    refute call.ended?
    assert_instance_of Time, call.answer_time
  end

  def test_handle_hangup_transitions_to_ended
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_hangup("NORMAL_CLEARING")

    assert_equal :ended, call.state
    refute call.alive?
    refute call.active?
    assert call.ended?
    assert_equal "NORMAL_CLEARING", call.end_reason
    assert_instance_of Time, call.end_time
  end

  def test_answered_true_after_hangup_if_was_answered
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_answer
    call.handle_hangup("NORMAL_CLEARING")

    assert call.answered?
    assert call.ended?
  end

  def test_on_answer_callback
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    callback_called = false
    call.on_answer { callback_called = true }
    call.handle_answer

    assert callback_called
  end

  def test_on_end_callback
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    callback_called = false
    call.on_end { callback_called = true }
    call.handle_hangup("NORMAL_CLEARING")

    assert callback_called
  end

  def test_wait_for_answer_returns_true_on_answer
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    Thread.new {
      sleep 0.2
      call.handle_answer
    }

    result = call.wait_for_answer(timeout: 1)
    assert result
  end

  def test_wait_for_answer_returns_false_on_timeout
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    result = call.wait_for_answer(timeout: 0.2)
    refute result
  end

  def test_wait_for_end_returns_true_on_hangup
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    Thread.new {
      sleep 0.2
      call.handle_hangup("NORMAL_CLEARING")
    }

    result = call.wait_for_end(timeout: 1)
    assert result
  end

  def test_dtmf_buffering
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_dtmf("1")
    call.handle_dtmf("2")
    call.handle_dtmf("3")

    digits = call.receive_dtmf(count: 3, timeout: 1)
    assert_equal "123", digits
  end

  def test_dtmf_timeout
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_dtmf("1")

    digits = call.receive_dtmf(count: 3, timeout: 0.2)
    assert_equal "1", digits
  end

  def test_inbound_outbound_direction
    inbound = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    outbound = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    assert inbound.inbound?
    refute inbound.outbound?
    refute outbound.inbound?
    assert outbound.outbound?
  end

  def test_answer_only_works_for_inbound_offered
    inbound = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    outbound = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    inbound.answer
    outbound.answer

    # Only inbound should have sent the answer command
    answer_commands = @connection.commands_sent.select { |c| c.include?("answer") }
    assert_equal 1, answer_commands.length
  end

  def test_hangup_sends_hangup_cause_header
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.hangup("USER_BUSY")

    command = @connection.commands_sent.last
    assert_match(/call-command: hangup/, command)
    assert_match(/hangup-cause: USER_BUSY/, command)
  end

  def test_hangup_defaults_to_normal_clearing
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.hangup

    command = @connection.commands_sent.last
    assert_match(/hangup-cause: NORMAL_CLEARING/, command)
  end

  def test_reject_busy_uses_user_busy_cause
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.reject(:busy)

    command = @connection.commands_sent.last
    assert_match(/hangup-cause: USER_BUSY/, command)
  end

  def test_reject_decline_uses_call_rejected_cause
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.reject(:decline)

    command = @connection.commands_sent.last
    assert_match(/hangup-cause: CALL_REJECTED/, command)
  end

  def test_send_dtmf_defaults_to_wait_true
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.send_dtmf("123")

    command = @connection.commands_sent.last
    assert_match(/execute-app-name: playback/, command)
    assert_match(/event-lock: true/, command)
  end

  def test_send_dtmf_with_wait_false_omits_event_lock
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.send_dtmf("123", wait: false)

    command = @connection.commands_sent.last
    assert_match(/execute-app-name: playback/, command)
    refute_match(/event-lock/, command)
  end

  def test_play_audio_defaults_to_wait_true
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.play_audio("/tmp/test.wav")

    command = @connection.commands_sent.last
    assert_match(/execute-app-name: playback/, command)
    assert_match(/execute-app-arg: \/tmp\/test.wav/, command)
    assert_match(/event-lock: true/, command)
  end

  def test_play_audio_with_wait_false_omits_event_lock
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.play_audio("/tmp/test.wav", wait: false)

    command = @connection.commands_sent.last
    assert_match(/execute-app-name: playback/, command)
    refute_match(/event-lock/, command)
  end
end
