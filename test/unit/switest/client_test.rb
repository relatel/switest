# frozen_string_literal: true

require_relative "../../test_helper"

class Switest::ClientTest < Minitest::Test
  def setup
    @session = Switest::MockSession.new
    @client = Switest::Client.new
    # Inject mock session directly
    @client.instance_variable_set(:@session, @session)
    Switest::Session.call_registry = @client.calls
  end

  def teardown
    Switest::Session.call_registry = nil
    Switest::Session.offer_handler = nil
    Switest::Session.connection_promise = nil
  end

  def test_dial_sets_origination_uuid
    call = @client.dial(to: "sofia/gateway/test/123")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert command, "Should have sent originate command"
    assert_match(/origination_uuid=#{call.id}/, command)
  end

  def test_dial_uses_park_application
    @client.dial(to: "sofia/gateway/test/123")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/&park\(\)/, command, "Should use &park()")
  end

  def test_dial_sets_caller_id_from_plain_number
    @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_dial_sets_return_ring_ready
    @client.dial(to: "sofia/gateway/test/123")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/return_ring_ready=true/, command)
  end

  def test_dial_sets_originate_timeout
    @client.dial(to: "sofia/gateway/test/123", timeout: 30)

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/originate_timeout=30/, command)
  end

  def test_dial_omits_originate_timeout_when_nil
    @client.dial(to: "sofia/gateway/test/123")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    refute_match(/originate_timeout/, command)
  end

  def test_dial_without_from_omits_caller_id
    @client.dial(to: "sofia/gateway/test/123")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    refute_match(/origination_caller_id/, command)
  end

  def test_dial_headers_prefixed_with_sip_h
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "Privacy" => "user;id", "X-Custom" => "value" }
    )

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/sip_h_Privacy=user;id/, command)
    assert_match(/sip_h_X-Custom=value/, command)
  end

  def test_dial_returns_call_object
    call = @client.dial(to: "sofia/gateway/test/123")

    assert_instance_of Switest::Call, call
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

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=Doe/, command)
    assert_match(/origination_caller_id_name=John/, command)
  end

  def test_dial_parses_display_name_with_angle_bracketed_sip_uri
    @client.dial(to: "sofia/gateway/test/123", from: "Display Name <sip:user@host>")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:user@host/, command)
    assert_match(/origination_caller_id_name='Display Name'/, command)
    assert_match(/sip_from_uri=sip:user@host/, command)
    assert_match(/sip_from_display='Display Name'/, command)
  end

  def test_dial_parses_number_only_in_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "<+4512345678>")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_dial_parses_name_with_empty_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "Jane Smith <>")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    refute_match(/origination_caller_id_number/, command)
    refute_match(/origination_caller_id_name/, command)
  end

  def test_dial_parses_sip_uri_with_display_name
    @client.dial(to: "sofia/gateway/test/123", from: "gibberish sip:+4522334455@abc.qq")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:\+4522334455@abc.qq/, command)
    assert_match(/origination_caller_id_name=gibberish/, command)
    assert_match(/sip_from_uri=sip:\+4522334455@abc.qq/, command)
    assert_match(/sip_from_display=gibberish/, command)
  end

  def test_dial_parses_sip_uri_without_display_name
    @client.dial(to: "sofia/gateway/test/123", from: "sip:anonymous@anonymous.invalid")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:anonymous@anonymous.invalid/, command)
    assert_match(/sip_from_uri=sip:anonymous@anonymous.invalid/, command)
    refute_match(/origination_caller_id_name/, command)
    refute_match(/sip_from_display/, command)
  end

  def test_dial_parses_sip_uri_with_plus_in_user
    @client.dial(to: "sofia/gateway/test/123", from: "sip:+4512345678@example.com")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=sip:\+4512345678@example.com/, command)
    assert_match(/sip_from_uri=sip:\+4512345678@example.com/, command)
    refute_match(/origination_caller_id_name/, command)
    refute_match(/sip_from_display/, command)
  end

  def test_dial_from_with_commas_no_brackets
    @client.dial(to: "sofia/gateway/test/123", from: "Doe, John")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=John/, command)
    assert_match(/origination_caller_id_name=\^\^.Doe./, command)
  end

  def test_dial_escapes_header_with_commas
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "X-Custom" => "one,two,three" }
    )

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/sip_h_X-Custom=one\\,two\\,three/, command)
  end

  def test_dial_escapes_header_with_spaces_and_brackets
    @client.dial(
      to: "sofia/gateway/test/123",
      headers: { "P-Asserted-Identity" => "<sip:+1234@example.com>" }
    )

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/sip_h_P-Asserted-Identity='<sip:\+1234@example.com>'/, command)
  end

  def test_dial_simple_from_not_escaped
    @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    command = @session.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    refute_match(/origination_caller_id_number='/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
  end

  def test_connected_returns_true_when_session_set
    assert @client.connected?
  end

  def test_connected_returns_false_when_no_session
    client = Switest::Client.new
    refute client.connected?
  end

  def test_events_routed_by_uuid_via_session
    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    # Simulate events via Session's on_event
    call_a.handle_dtmf("1")
    call_b.handle_dtmf("9")

    assert_equal "1", call_a.receive_dtmf(count: 1, timeout: 0.1)
    assert_equal "9", call_b.receive_dtmf(count: 1, timeout: 0.1)
  end

  def test_answer_events_routed_per_call
    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    call_a.handle_answer
    call_a.handle_callstate("ACTIVE")

    assert call_a.answered?, "Call A should be answered"
    refute call_b.answered?, "Call B should NOT be answered"
  end

  def test_hangup_events_routed_per_call
    call_a = @client.dial(to: "sofia/gateway/test/111")
    call_b = @client.dial(to: "sofia/gateway/test/222")

    call_a.handle_hangup("NORMAL_CLEARING")

    assert call_a.ended?, "Call A should be ended"
    refute call_b.ended?, "Call B should NOT be ended"
  end
end
