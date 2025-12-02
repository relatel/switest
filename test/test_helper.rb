# frozen_string_literal: true

$LOAD_PATH.unshift("lib")

Bundler.require(:default, :test) if defined?(Bundler)

require "minitest/autorun"
require "timeout"
require "securerandom"
require "switest"

class Minitest::Test
  include Switest
end

# Mock client for testing without a real FreeSWITCH server
module Switest
  module ESL
    class MockConnection
      def initialize(host:, port:, password:, logger: nil)
        @connected = false
      end

      def connect
        @connected = true
      end

      def close
        @connected = false
      end

      alias disconnect close

      def connected?
        @connected
      end

      def sendmsg(uuid, app:, arg: nil, async: false)
        # No-op in mock
      end

      def bgapi(command)
        # No-op in mock
      end
    end

    class MockClient
      attr_reader :active_calls

      def initialize(host: nil, port: nil, password: nil, logger: nil)
        @active_calls = Concurrent::Map.new
        @offer_callbacks = []
        @connected = false
        @connection = MockConnection.new(host: host, port: port, password: password)
      end

      def connect
        @connection.connect
        @connected = true
      end

      def disconnect
        @connection.disconnect
        @connected = false
      end

      def connected?
        @connected
      end

      def dial(to:, from: nil, headers: {})
        call = MockCall.new(@connection, to: to, from: from, headers: headers)
        @active_calls[call.id] = call
        call
      end

      def on_offer(&block)
        @offer_callbacks << block
      end

      # Test helper: simulate an inbound call offer
      def simulate_offer(to:, from: nil, headers: {})
        call = MockCall.new(@connection, to: to, from: from, headers: headers)
        @active_calls[call.id] = call
        @offer_callbacks.each { |cb| cb.call(call) }
        call
      end
    end

    class MockCall < Call
      def initialize(connection, uuid: nil, to: nil, from: nil, headers: {})
        @connection = connection
        @id = uuid || SecureRandom.uuid
        @to = to
        @from = from
        @headers = headers
        @start_time = Time.now
        @answer_time = nil
        @end_reason = nil
        @state = :offered
        @answer_callbacks = Concurrent::Array.new
        @end_callbacks = Concurrent::Array.new
        @input_complete_callbacks = Concurrent::Array.new
        @mutex = Mutex.new
      end

      def answer
        handle_answered
      end

      def hangup(headers = {})
        handle_end(:hangup)
      end

      def reject(reason = :decline, headers = {})
        handle_end(:reject)
      end

      def play_audio(url)
        # No-op in mock
      end

      def receive_dtmf(max_digits:, timeout: 5, terminator: "#")
        # Return nil in mock - use simulate_dtmf to test
        @pending_dtmf
      end

      # Test helpers
      def simulate_answer
        handle_answered
      end

      def simulate_end(reason = :hangup)
        handle_end(reason)
      end

      def simulate_dtmf(digits)
        @pending_dtmf = digits
        handle_input_complete(digits)
      end
    end
  end
end
