# frozen_string_literal: true

# Integration tests for ESL connection against real FreeSWITCH
#
# Requires FreeSWITCH running:
#   docker compose up -d
#
# Run with:
#   ruby -Ilib -Itest test/integration/esl_connection_test.rb

$LOAD_PATH.unshift("lib")

require "minitest/autorun"
require "switest2"

class ESLConnectionIntegrationTest < Minitest::Test
  def setup
    @connection = Switest2::ESL::Connection.new(
      host: ENV.fetch("FREESWITCH_HOST", "127.0.0.1"),
      port: ENV.fetch("FREESWITCH_PORT", 8021).to_i,
      password: ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
    )
  end

  def teardown
    @connection&.disconnect
  end

  def test_connect_and_authenticate
    @connection.connect
    assert @connection.connected?, "Should be connected after connect"
  end

  def test_disconnect
    @connection.connect
    assert @connection.connected?

    @connection.disconnect
    refute @connection.connected?, "Should be disconnected after disconnect"
  end

  def test_api_status
    @connection.connect
    response = @connection.api("status")

    assert response.include?("UP"), "Status should indicate FreeSWITCH is up"
  end

  def test_api_global_getvar
    @connection.connect
    response = @connection.api("global_getvar hostname")

    # Should return something (the hostname)
    refute response.empty?, "Should return hostname"
  end

  def test_api_error_handling
    @connection.connect

    error = assert_raises(Switest2::Error) do
      @connection.api("nonexistent_command_xyz")
    end

    assert error.message.include?("-ERR"), "Should include error message"
  end

  def test_bgapi
    @connection.connect
    response = @connection.bgapi("status")

    # bgapi returns immediately with job UUID
    assert response[:headers]["Reply-Text"]&.include?("+OK"),
           "bgapi should return +OK"
  end

  def test_authentication_failure
    bad_connection = Switest2::ESL::Connection.new(
      host: ENV.fetch("FREESWITCH_HOST", "127.0.0.1"),
      port: ENV.fetch("FREESWITCH_PORT", 8021).to_i,
      password: "wrong_password"
    )

    error = assert_raises(Switest2::AuthenticationError) do
      bad_connection.connect
    end

    assert error.message.include?("Authentication failed") ||
           error.message.include?("-ERR"),
           "Should indicate authentication failure"
  ensure
    bad_connection&.disconnect
  end

  def test_connection_refused
    bad_connection = Switest2::ESL::Connection.new(
      host: "127.0.0.1",
      port: 59999,  # Unlikely to be in use
      password: "ClueCon"
    )

    assert_raises(Errno::ECONNREFUSED, Errno::ETIMEDOUT) do
      bad_connection.connect
    end
  end
end
