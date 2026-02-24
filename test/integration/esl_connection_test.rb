# frozen_string_literal: true

# Integration tests for ESL connection against real FreeSWITCH
#
# Run with:
#   rake integration

require_relative "../integration_helper"

class ESLConnectionIntegrationTest < Minitest::Test
  def run(...)
    Sync { super }
  end

  def setup
    config = Switest.configuration
    @connection = Switest::ESL::Connection.new(
      host: config.host,
      port: config.port,
      password: config.password
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

    error = assert_raises(Switest::Error) do
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
    config = Switest.configuration
    bad_connection = Switest::ESL::Connection.new(
      host: config.host,
      port: config.port,
      password: "wrong_password"
    )

    error = assert_raises(Switest::AuthenticationError) do
      bad_connection.connect
    end

    assert error.message.include?("Authentication failed") ||
           error.message.include?("-ERR"),
           "Should indicate authentication failure"
  ensure
    bad_connection&.disconnect
  end

  def test_connection_refused
    bad_connection = Switest::ESL::Connection.new(
      host: "127.0.0.1",
      port: 59999,  # Unlikely to be in use
      password: "ClueCon"
    )

    assert_raises(Errno::ECONNREFUSED, Errno::ETIMEDOUT) do
      bad_connection.connect
    end
  end
end
