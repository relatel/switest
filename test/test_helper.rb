# frozen_string_literal: true

$LOAD_PATH.unshift("lib")

Bundler.require(:default, :test) if defined?(Bundler)

require "minitest/autorun"
require "timeout"
require "switest"

class Minitest::Test
  include Switest
end

# Mock client for testing without a real Rayo server
module Switest
  module Rayo
    class MockClient
      attr_reader :active_calls

      def initialize
        @active_calls = Concurrent::Map.new
        @offer_callbacks = []
        @connected = true
      end

      def connect
        @connected = true
      end

      def disconnect
        @connected = false
      end

      def connected?
        @connected
      end

      def dial(to:, from: nil, headers: {})
        call = MockCall.new(self, to: to, from: from, headers: headers)
        @active_calls[call.id] = call
        call
      end

      def on_offer(&block)
        @offer_callbacks << block
      end

      def send_command(command)
        # No-op in mock
      end

      def send_command_sync(command, timeout: 5)
        # Return a mock response
        MockResponse.new
      end

      # Test helper: simulate an inbound call offer
      def simulate_offer(to:, from: nil, headers: {})
        call = MockCall.new(self, to: to, from: from, headers: headers)
        @active_calls[call.id] = call
        @offer_callbacks.each { |cb| cb.call(call) }
        call
      end
    end

    class MockCall < Call
      def initialize(client, to: nil, from: nil, headers: {}, jid: nil)
        @client = client
        @id = SecureRandom.uuid
        @jid = jid || Blather::JID.new("#{@id}@calls.localhost")
        @to = to
        @from = from
        @headers = headers
        @start_time = Time.now
        @answer_time = nil
        @end_reason = nil
        @state = :offered
        @answer_callbacks = Concurrent::Array.new
        @end_callbacks = Concurrent::Array.new
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

      # Test helpers
      def simulate_answer
        handle_answered
      end

      def simulate_end(reason = :hangup)
        handle_end(reason)
      end
    end

    class MockResponse
      def find_first(xpath, ns: nil)
        MockRefNode.new
      end

      def type
        :result
      end
    end

    class MockRefNode
      def [](key)
        "mock-call-id@calls.localhost" if key == "uri" || key == "id"
      end
    end
  end
end
