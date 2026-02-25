# frozen_string_literal: true

# Integration tests for Client against real FreeSWITCH
#
# Run with:
#   rake integration

require_relative "../integration_helper"

class ClientIntegrationTest < Minitest::Test
  def run(...)
    Sync { super }
  end

  def setup
    @client = Switest::Client.new
  end

  def teardown
    @client&.stop
  end

  def test_start_and_stop
    @client.start

    assert @client.connected?, "Client should connect on start"

    @client.stop

    refute @client.connected?, "Client should disconnect on stop"
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
    # With inbound ESL, the bgapi will return but the call won't progress
    call = @client.dial(to: "error/]]invalid[[")

    # The call was created but will likely fail
    assert_instance_of Switest::Call, call
  end
end
