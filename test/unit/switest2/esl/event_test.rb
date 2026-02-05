# frozen_string_literal: true

require_relative "../../../switest2_test_helper"

class Switest2::ESL::EventTest < Minitest::Test
  def test_parse_basic_event
    raw = <<~EVENT
      Event-Name: CHANNEL_ANSWER
      Unique-ID: abc123
      Caller-Caller-ID-Number: +4512345678
      Caller-Destination-Number: 1000
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "CHANNEL_ANSWER", event.name
    assert_equal "abc123", event.uuid
    assert_equal "+4512345678", event.caller_id
    assert_equal "1000", event.destination
  end

  def test_parse_url_encoded_values
    raw = <<~EVENT
      Event-Name: CHANNEL_CREATE
      Caller-Caller-ID-Name: John%20Doe
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "John Doe", event["Caller-Caller-ID-Name"]
  end

  def test_parse_returns_nil_for_empty_data
    assert_nil Switest2::ESL::Event.parse(nil)
    assert_nil Switest2::ESL::Event.parse("")
  end

  def test_uuid_prefers_unique_id
    raw = <<~EVENT
      Event-Name: CHANNEL_ANSWER
      Unique-ID: unique-id-value
      Channel-Call-UUID: channel-uuid-value
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "unique-id-value", event.uuid
  end

  def test_uuid_falls_back_to_channel_call_uuid
    raw = <<~EVENT
      Event-Name: CHANNEL_ANSWER
      Channel-Call-UUID: channel-uuid-value
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "channel-uuid-value", event.uuid
  end

  def test_variable_accessor
    raw = <<~EVENT
      Event-Name: CHANNEL_ANSWER
      variable_sip_from_uri: sip:alice@example.com
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "sip:alice@example.com", event.variable("sip_from_uri")
  end

  def test_hangup_cause
    raw = <<~EVENT
      Event-Name: CHANNEL_HANGUP_COMPLETE
      Hangup-Cause: NORMAL_CLEARING
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "NORMAL_CLEARING", event.hangup_cause
  end

  def test_call_direction
    raw = <<~EVENT
      Event-Name: CHANNEL_CREATE
      Call-Direction: inbound
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "inbound", event.call_direction
  end

  def test_bracket_accessor
    raw = <<~EVENT
      Event-Name: CHANNEL_CREATE
      Custom-Header: custom-value
    EVENT

    event = Switest2::ESL::Event.parse(raw)

    assert_equal "custom-value", event["Custom-Header"]
  end
end
