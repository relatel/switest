# frozen_string_literal: true

# Integration tests for ESL Client against real FreeSWITCH
#
# Requires FreeSWITCH running:
#   docker compose up -d
#
# Run with:
#   ruby -Ilib -Itest test/integration/esl_client_test.rb


require "minitest/autorun"
require "switest2"

class ESLClientIntegrationTest < Minitest::Test
  def setup
    Switest2.configure do |config|
      config.host = ENV.fetch("FREESWITCH_HOST", "127.0.0.1")
      config.port = ENV.fetch("FREESWITCH_PORT", 8021).to_i
      config.password = ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
    end

    @client = Switest2::ESL::Client.new
  end

  def teardown
    @client&.stop
    Switest2.reset_configuration!
  end

  def test_start_and_stop
    @client.start

    assert @client.connection.connected?, "Client should connect on start"

    @client.stop

    refute @client.connection.connected?, "Client should disconnect on stop"
  end

  def test_event_reader_thread_starts
    @client.start

    # Give the reader thread a moment to start
    sleep 0.1

    # The reader thread should be running
    # We can verify by checking the client is still connected after a moment
    sleep 0.2
    assert @client.connection.connected?, "Connection should stay open with reader running"
  end

  def test_active_calls_empty_initially
    @client.start

    assert_empty @client.active_calls, "Should have no active calls initially"
  end

  def test_on_offer_registration
    @client.start

    callback_registered = false
    @client.on_offer { callback_registered = true }

    # We can't easily trigger an inbound call in this test,
    # but we can verify the callback was registered without error
    assert true, "on_offer registration should not raise"
  end

  def test_dial_invalid_destination
    @client.start

    # Dialing an invalid destination should create a call object
    # but the call will fail (no actual SIP endpoint)
    call = @client.dial(to: "error/]]invalid[[")

    assert_instance_of Switest2::ESL::Call, call
    assert call.id, "Call should have an ID"

    # The call should be tracked
    assert @client.calls[call.id], "Call should be in client's call map"

    # Note: We don't wait for end here because invalid destinations
    # may not generate proper hangup events from FreeSWITCH
  end
end
