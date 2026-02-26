# frozen_string_literal: true

require_relative "../../test_helper"

class Switest::EventsTest < Minitest::Test
  def setup
    @events = Switest::Events.new
  end

  def test_once_triggers_only_once
    count = 0
    @events.once(:test) { count += 1 }
    @events.emit(:test, {})
    @events.emit(:test, {})
    assert_equal 1, count
  end

  def test_guard_hash_equality_match
    triggered = false
    @events.once(:call, { to: "71999999" }) { triggered = true }
    @events.emit(:call, { to: "71999999" })
    assert triggered
  end

  def test_guard_hash_equality_no_match
    triggered = false
    @events.once(:call, { to: "71999999" }) { triggered = true }
    @events.emit(:call, { to: "22334455" })
    refute triggered
  end

  def test_guard_regex_match
    triggered = false
    @events.once(:call, { to: /^719/ }) { triggered = true }
    @events.emit(:call, { to: "71999999" })
    assert triggered
  end

  def test_guard_regex_no_match
    triggered = false
    @events.once(:call, { to: /^719/ }) { triggered = true }
    @events.emit(:call, { to: "22334455" })
    refute triggered
  end

  def test_guard_array_match
    triggered = false
    @events.once(:call, { status: [:ringing, :early] }) { triggered = true }
    @events.emit(:call, { status: :ringing })
    assert triggered
  end

  def test_guard_array_no_match
    triggered = false
    @events.once(:call, { status: [:ringing, :early] }) { triggered = true }
    @events.emit(:call, { status: :answered })
    refute triggered
  end

  def test_guard_proc_match
    triggered = false
    @events.once(:call, { to: ->(v) { v.length > 5 } }) { triggered = true }
    @events.emit(:call, { to: "71999999" })
    assert triggered
  end

  def test_guard_proc_no_match
    triggered = false
    @events.once(:call, { to: ->(v) { v.length > 10 } }) { triggered = true }
    @events.emit(:call, { to: "719" })
    refute triggered
  end

  def test_multiple_guards_all_must_match
    triggered = false
    @events.once(:call, { to: /^719/, from: "12345" }) { triggered = true }
    @events.emit(:call, { to: "71999999", from: "12345" })
    assert triggered
  end

  def test_multiple_guards_partial_match_fails
    triggered = false
    @events.once(:call, { to: /^719/, from: "12345" }) { triggered = true }
    @events.emit(:call, { to: "71999999", from: "99999" })
    refute triggered
  end

  def test_emit_passes_data_to_handler
    received = nil
    @events.once(:test) { |data| received = data }
    @events.emit(:test, { foo: "bar" })
    assert_equal({ foo: "bar" }, received)
  end

  def test_no_guards_matches_everything
    triggered = false
    @events.once(:call) { triggered = true }
    @events.emit(:call, { to: "anything", from: "whatever" })
    assert triggered
  end
end
