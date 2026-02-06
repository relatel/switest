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

  def test_handle_hangup_merges_headers
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.handle_hangup("NORMAL_CLEARING", {
      "variable_billsec" => "120",
      "variable_duration" => "125"
    })

    assert_equal "120", call.headers["variable_billsec"]
    assert_equal "125", call.headers["variable_duration"]
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

  def test_handle_bridge_sets_bridged
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    refute call.bridged?
    call.handle_bridge
    assert call.bridged?
  end

  def test_handle_bridge_ignored_after_hangup
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    call.handle_hangup("NORMAL_CLEARING")
    call.handle_bridge

    # bridged? returns true because hangup releases the bridged latch,
    # but the handle_bridge early-returns without setting @bridged via mutex
    # Actually let's check: hangup counts down the latch but doesn't set @bridged
    # handle_bridge returns early because state == :ended
    # So bridged? should be false (the flag), but wait_for_bridge would return
    # because the latch was released by hangup
    refute call.bridged?, "Should not be bridged after hangup"
  end

  def test_on_bridge_callback
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    callback_called = false
    call.on_bridge { callback_called = true }
    call.handle_bridge

    assert callback_called
  end

  def test_wait_for_bridge_returns_true_on_bridge
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    Thread.new {
      sleep 0.2
      call.handle_bridge
    }

    result = call.wait_for_bridge(timeout: 1)
    assert result
  end

  def test_wait_for_bridge_returns_false_on_timeout
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    result = call.wait_for_bridge(timeout: 0.2)
    refute result
  end

  def test_wait_for_bridge_unblocks_on_hangup
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound
    )

    Thread.new {
      sleep 0.2
      call.handle_hangup("NORMAL_CLEARING")
    }

    # Should unblock even though bridge never happened
    result = call.wait_for_bridge(timeout: 1)
    refute result, "Should return false since call ended without bridging"
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

    inbound.answer(wait: false)
    outbound.answer(wait: false)

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

    call.hangup("USER_BUSY", wait: false)

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

    call.hangup(wait: false)

    command = @connection.commands_sent.last
    assert_match(/hangup-cause: NORMAL_CLEARING/, command)
  end

  def test_reject_busy_uses_user_busy_cause
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.reject(:busy, wait: false)

    command = @connection.commands_sent.last
    assert_match(/hangup-cause: USER_BUSY/, command)
  end

  def test_reject_decline_uses_call_rejected_cause
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound
    )

    call.reject(:decline, wait: false)

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
    assert_match(%r{execute-app-arg: tone_stream://d=200;w=250;123}, command)
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
    assert_match(%r{execute-app-arg: tone_stream://d=200;w=250;123}, command)
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
