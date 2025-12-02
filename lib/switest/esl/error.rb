# frozen_string_literal: true

module Switest
  module ESL
    # Base error class for ESL library
    class Error < StandardError; end

    # Raised when connection to FreeSWITCH fails
    class ConnectionError < Error; end

    # Raised when authentication fails
    class AuthError < Error; end

    # Raised when a command fails
    class CommandError < Error; end

    # Raised when an operation times out
    class TimeoutError < Error; end

    # Raised when an operation is performed on an invalid call state
    class CallError < Error; end
  end
end
