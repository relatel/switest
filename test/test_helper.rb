# frozen_string_literal: true

require "minitest/autorun"
require "async"

require "switest"

# Run every test inside an async reactor so fiber-based primitives
# (Async::Variable, Async::Condition, Async::Queue) work transparently.
module AsyncTestRunner
  def run(...)
    Sync { super }
  end
end
Minitest::Test.prepend(AsyncTestRunner)

# Mock ESL Connection for unit tests
module Switest
  module ESL
    class MockConnection
      attr_reader :commands_sent, :event_handlers

      def initialize
        @commands_sent = []
        @connected = true
        @event_handlers = []
      end

      def connect
        self
      end

      def disconnect
        @connected = false
      end

      def connected?
        @connected
      end

      def send_command(cmd)
        @commands_sent << cmd
        { headers: { "Reply-Text" => "+OK" }, body: nil }
      end

      def api(cmd)
        @commands_sent << "api #{cmd}"
        "+OK"
      end

      def bgapi(cmd)
        @commands_sent << "bgapi #{cmd}"
        { headers: { "Reply-Text" => "+OK" }, body: nil }
      end

      def on_event(&block)
        @event_handlers << block
      end

      # Simulate an event from FreeSWITCH
      def simulate_event(body)
        response = { headers: {}, body: body }
        @event_handlers.each { |h| h.call(response) }
      end
    end
  end
end
