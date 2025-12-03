# frozen_string_literal: true

module Switest
  # Base error class for all Switest errors.
  class Error < StandardError; end

  # ESL-related errors
  module ESL
    # Base class for ESL errors.
    class Error < Switest::Error; end

    # Raised when connection to FreeSWITCH fails.
    class ConnectionError < Error; end

    # Raised when authentication fails.
    class AuthError < Error; end

    # Raised when a command times out.
    class TimeoutError < Error; end

    # Raised when an operation is attempted on a disconnected socket.
    class DisconnectedError < Error; end

    # Raised for call-related errors.
    class CallError < Error; end

    # Raised when a call operation is invalid for current state.
    class InvalidStateError < CallError
      attr_reader :current_state, :required_state

      def initialize(message = nil, current_state: nil, required_state: nil)
        @current_state = current_state
        @required_state = required_state
        super(message || default_message)
      end

      private

      def default_message
        "Invalid call state: #{current_state}, required: #{required_state}"
      end
    end

    # Raised when parsing ESL messages fails.
    class ParseError < Error; end
  end

  # Agent-related errors
  class AgentError < Error; end

  # Raised when an agent operation times out.
  class AgentTimeoutError < AgentError; end

  # Raised when no call is available for an operation.
  class NoCallError < AgentError; end

  # Configuration errors
  class ConfigurationError < Error; end
end
