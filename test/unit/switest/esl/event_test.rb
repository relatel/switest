# frozen_string_literal: true

require_relative "../../../test_helper"

class EventTest < Minitest::Test
  # Simple packet with just headers (no body)
  def test_parse_headers_simple
    raw = "Event-Name: HEARTBEAT\nCore-UUID: abc123"
    headers = Switest::ESL::Event.parse_headers(raw)

    assert_equal "HEARTBEAT", headers["Event-Name"]
    assert_equal "abc123", headers["Core-UUID"]
  end

  # URL-encoded header values
  def test_parse_headers_url_encoded
    raw = "Caller-Caller-ID-Name: John%20Doe\nVariable: Hello%2C%20World"
    headers = Switest::ESL::Event.parse_headers(raw)

    assert_equal "John Doe", headers["Caller-Caller-ID-Name"]
    assert_equal "Hello, World", headers["Variable"]
  end

  # Ensure + is NOT decoded as space (ESL uses %20 for space)
  def test_parse_headers_plus_not_decoded
    raw = "Phone: +45123456"
    headers = Switest::ESL::Event.parse_headers(raw)

    assert_equal "+45123456", headers["Phone"]
  end

  # Parse complete message with headers and body
  def test_parse_with_body
    raw = <<~ESL
      Content-Type: api/response
      Content-Length: 12

      +OK Success
    ESL

    event = Switest::ESL::Event.parse(raw)

    assert_equal "api/response", event.name
    assert_equal "+OK Success\n", event.body
  end

  # Parse text/event-plain body (second-level parsing)
  def test_parse_event_plain_headers_only
    # Event body contains headers only (no event body)
    body = <<~BODY.chomp
      Event-Name: CHANNEL_ANSWER
      Unique-ID: abc-123
      Caller-Direction: inbound
    BODY

    event_headers, event_body = Switest::ESL::Event.parse_event_plain(body)

    assert_equal "CHANNEL_ANSWER", event_headers["Event-Name"]
    assert_equal "abc-123", event_headers["Unique-ID"]
    assert_equal "inbound", event_headers["Caller-Direction"]
    assert_nil event_body
  end

  # Parse text/event-plain with event body
  def test_parse_event_plain_with_body
    # Event has headers AND a body (e.g., RECV_RTCP_MESSAGE)
    body = <<~BODY.chomp
      Event-Name: RECV_RTCP_MESSAGE
      Unique-ID: abc-123
      Content-Length: 15

      RTCP packet data
    BODY

    event_headers, event_body = Switest::ESL::Event.parse_event_plain(body)

    assert_equal "RECV_RTCP_MESSAGE", event_headers["Event-Name"]
    assert_equal "abc-123", event_headers["Unique-ID"]
    assert_equal "15", event_headers["Content-Length"]
    assert_equal "RTCP packet dat", event_body  # 15 bytes
  end

  # Real-world CHANNEL_ANSWER event (simplified)
  def test_parse_channel_answer_event
    body = <<~BODY.chomp
      Event-Name: CHANNEL_ANSWER
      Core-UUID: 1234-5678
      FreeSWITCH-Hostname: fs01
      FreeSWITCH-IPv4: 10.0.0.1
      Event-Date-Local: 2024-01-15%2010%3A30%3A00
      Unique-ID: call-uuid-123
      Call-Direction: inbound
      Caller-Caller-ID-Number: %2B4512345678
      Caller-Destination-Number: 1000
    BODY

    event_headers, event_body = Switest::ESL::Event.parse_event_plain(body)

    assert_equal "CHANNEL_ANSWER", event_headers["Event-Name"]
    assert_equal "call-uuid-123", event_headers["Unique-ID"]
    assert_equal "inbound", event_headers["Call-Direction"]
    # URL-decoded values
    assert_equal "+4512345678", event_headers["Caller-Caller-ID-Number"]
    assert_equal "2024-01-15 10:30:00", event_headers["Event-Date-Local"]
    assert_nil event_body
  end

  # Event instance methods
  def test_event_uuid
    event = Switest::ESL::Event.new(
      name: "CHANNEL_ANSWER",
      headers: { "Unique-ID" => "abc-123" }
    )

    assert_equal "abc-123", event.uuid
  end

  def test_event_direction
    event = Switest::ESL::Event.new(
      name: "CHANNEL_CREATE",
      headers: { "Call-Direction" => "inbound" }
    )

    assert event.inbound?
    refute event.outbound?
  end

  def test_event_variable_access
    event = Switest::ESL::Event.new(
      name: "CHANNEL_EXECUTE_COMPLETE",
      headers: {
        "variable_sip_from_user" => "alice",
        "variable_hangup_cause" => "NORMAL_CLEARING"
      }
    )

    assert_equal "alice", event.variable("sip_from_user")
    assert_equal "NORMAL_CLEARING", event.variable("hangup_cause")
  end
end
