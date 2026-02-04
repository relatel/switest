# frozen_string_literal: true

require_relative "../../switest2_test_helper"

class Switest2::ESL::ClientTest < Minitest::Test
  def setup
    @connection = Switest2::ESL::MockConnection.new
    @client = Switest2::ESL::Client.new(@connection)
  end

  def test_dial_sets_origination_uuid
    call = @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert command, "Should have sent originate command"
    assert_match(/origination_uuid=#{call.id}/, command)
  end

  def test_dial_sets_caller_id_number_and_name
    @client.dial(to: "sofia/gateway/test/123", from: "+4512345678")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    assert_match(/origination_caller_id_number=\+4512345678/, command)
    assert_match(/origination_caller_id_name=\+4512345678/, command)
    assert_match(/sip_from_user=\+4512345678/, command)
  end

  def test_dial_without_from_omits_caller_id
    @client.dial(to: "sofia/gateway/test/123")

    command = @connection.commands_sent.find { |c| c.include?("originate") }
    refute_match(/origination_caller_id/, command)
    refute_match(/sip_from_user/, command)
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

    assert_instance_of Switest2::ESL::Call, call
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
end
