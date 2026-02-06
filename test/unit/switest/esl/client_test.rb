# frozen_string_literal: true

require_relative "../../../switest_test_helper"

class Switest::ESL::ClientTest < Minitest::Test
  def setup
    @connection = Switest::ESL::MockConnection.new
    @client = Switest::ESL::Client.new(@connection)
  end

  def test_dial_sets_origination_uuid
    call = @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert command, "Should have sent originate command"
    assert_match(/origination_uuid=#{call.id}/, command)
  end

  def test_dial_sets_caller_id_from_plain_number
    @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_dial_sets_return_ring_ready
    @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/return_ring_ready=true/, command)
  end

  def test_dial_sets_originate_timeout
    @client.dial(to: "sofia/gateway/test/123", timeout: 30)

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/originate_timeout=30/, command)
  end

  def test_dial_omits_originate_timeout_when_nil
    @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    refute_match(/originate_timeout/, command)
  end

  def test_dial_without_from_omits_caller_id
    @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    refute_match(/origination_caller_id/, command)
  end

  def test_dial_headers_prefixed_with_sip_h
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "Privacy" => "user;id", "X-Custom" => "value" }
    )

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/sip_h_Privacy=user;id/, command)
    assert_match(/sip_h_X-Custom=value/, command)
  end

  def test_dial_returns_call_object
    call = @client.dial(to: "sofia/gateway/test/123")

    assert_instance_of Switest::ESL::Call, call
    assert call.outbound?
    assert_equal "sofia/gateway/test/123", call.to
  end

  def test_dial_with_from_sets_call_from
    call = @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    assert_equal "+4512345678", call.from
  end

  def test_dial_tracks_call
    call = @client.dial(to: "sofia/gateway/test/123")

    assert_equal call, @client.calls[call.id]
  end

  def test_dial_from_without_brackets_sets_tel_vars
    @client.dial(to: "sofia/gateway/test/123", from: "John Doe")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # "John Doe" splits on last space: display="John", uri="Doe" → TEL
    assert_match(/origination_caller_id_number=Doe/, command)
    assert_match(/origination_caller_id_name=John/, command)
  end

  def test_dial_parses_display_name_with_angle_bracketed_sip_uri
    @client.dial(to: "sofia/gateway/test/123", from: "Display Name <sip:user@host>")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:user@host/, command)
    assert_match(/origination_caller_id_name='Display Name'/, command)
    assert_match(/sip_from_uri=sip:user@host/, command)
    assert_match(/sip_from_display='Display Name'/, command)
  end

  def test_dial_parses_number_only_in_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "<+4512345678>")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_dial_parses_name_with_empty_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "Jane Smith <>")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # Split on last space: display="Jane Smith", uri="<>" → strip brackets → empty → empty hash
    # Actually: "Jane Smith <>" splits on last space → display="Jane Smith", uri="<>"
    # Strip angle brackets from "<>" → "" → empty URI → empty hash
    refute_match(/origination_caller_id_number/, command)
    refute_match(/origination_caller_id_name/, command)
  end

  def test_dial_parses_sip_uri_with_display_name
    @client.dial(to: "sofia/gateway/test/123", from: "gibberish sip:+4522334455@abc.qq")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:\+4522334455@abc.qq/, command)
    assert_match(/origination_caller_id_name=gibberish/, command)
    assert_match(/sip_from_uri=sip:\+4522334455@abc.qq/, command)
    assert_match(/sip_from_display=gibberish/, command)
  end

  def test_dial_parses_sip_uri_without_display_name
    @client.dial(to: "sofia/gateway/test/123", from: "sip:anonymous@anonymous.invalid")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:anonymous@anonymous.invalid/, command)
    assert_match(/sip_from_uri=sip:anonymous@anonymous.invalid/, command)
    refute_match(/origination_caller_id_name/, command)
    refute_match(/sip_from_display/, command)
  end

  def test_dial_parses_sip_uri_with_plus_in_user
    @client.dial(to: "sofia/gateway/test/123", from: "sip:+4512345678@example.com")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:\+4512345678@example.com/, command)
    assert_match(/sip_from_uri=sip:\+4512345678@example.com/, command)
    refute_match(/origination_caller_id_name/, command)
    refute_match(/sip_from_display/, command)
  end

  def test_dial_from_with_commas_no_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "Doe, John")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # Splits on last space: display="Doe,", uri="John" → TEL
    assert_match(/origination_caller_id_number=John/, command)
    assert_match(/origination_caller_id_name=\^\^.Doe./, command)
  end

  def test_dial_escapes_header_with_commas
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "X-Custom" => "one,two,three" }
    )

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # Commas should be escaped with backslash in SIP headers
    assert_match(/sip_h_X-Custom=one\\,two\\,three/, command)
  end

  def test_dial_escapes_header_with_spaces_and_brackets
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "P-Asserted-Identity" => "<sip:+1234@example.com>" }
    )

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # Should be wrapped in quotes due to angle brackets
    assert_match(/sip_h_P-Asserted-Identity='<sip:\+1234@example.com>'/, command)
  end

  def test_dial_simple_from_not_escaped
    @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    # Simple value should NOT have quotes
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    refute_match(/origination_caller_id_number='/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_dtmf_events_are_isolated_by_uuid
    # Start the client to register event handlers
    @client.start

    # Create two calls with different UUIDs
    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    # Simulate DTMF event for call_a
    @connection.simulate_event(<<~EVENT)
      Event-Name: DTMF
      Unique-ID: #{call_a.id}
      DTMF-Digit: 1
    EVENT

    # Simulate DTMF event for call_b
    @connection.simulate_event(<<~EVENT)
      Event-Name: DTMF
      Unique-ID: #{call_b.id}
      DTMF-Digit: 9
    EVENT

    # Each call should only receive its own DTMF
    assert_equal "1", call_a.receive_dtmf(count: 1, timeout: 0.1)
    assert_equal "9", call_b.receive_dtmf(count: 1, timeout: 0.1)
  end

  def test_dtmf_events_for_unknown_uuid_are_ignored
    @client.start
    call = @client.dial(to: "sofia/gateway/test/123")

    # Simulate DTMF event for unknown UUID
    @connection.simulate_event(<<~EVENT)
      Event-Name: DTMF
      Unique-ID: unknown-uuid-xyz
      DTMF-Digit: 5
    EVENT

    # Our call should not receive this DTMF
    digits = call.receive_dtmf(count: 1, timeout: 0.1)
    assert_equal "", digits
  end

  def test_answer_events_are_isolated_by_uuid
    @client.start

    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    # Only answer call_a
    @connection.simulate_event(<<~EVENT)
      Event-Name: CHANNEL_ANSWER
      Unique-ID: #{call_a.id}
    EVENT

    assert call_a.answered?, "Call A should be answered"
    refute call_b.answered?, "Call B should NOT be answered"
  end

  def test_bridge_event_sets_call_bridged
    @client.start

    call = @client.dial(to: "sofia/gateway/test/123")

    @connection.simulate_event(<<~EVENT)
      Event-Name: CHANNEL_BRIDGE
      Unique-ID: #{call.id}
      Other-Leg-Unique-ID: other-leg-uuid
    EVENT

    assert call.bridged?, "Call should be bridged after CHANNEL_BRIDGE event"
  end

  def test_bridge_events_are_isolated_by_uuid
    @client.start

    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    # Only bridge call_a
    @connection.simulate_event(<<~EVENT)
      Event-Name: CHANNEL_BRIDGE
      Unique-ID: #{call_a.id}
    EVENT

    assert call_a.bridged?, "Call A should be bridged"
    refute call_b.bridged?, "Call B should NOT be bridged"
  end

  def test_hangup_events_are_isolated_by_uuid
    @client.start

    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    # Only hangup call_a
    @connection.simulate_event(<<~EVENT)
      Event-Name: CHANNEL_HANGUP_COMPLETE
      Unique-ID: #{call_a.id}
      Hangup-Cause: NORMAL_CLEARING
    EVENT

    assert call_a.ended?, "Call A should be ended"
    refute call_b.ended?, "Call B should NOT be ended"
  end
end
