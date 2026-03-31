# frozen_string_literal: true

require "minitest/autorun"
require "async"
require "async/promise"

require "switest"

Warning[:experimental] = false

# Run every test inside an async reactor so fiber-based primitives
# (Async::Variable, Async::Condition, Async::Queue) work transparently.
module AsyncTestRunner
  def run(...)
    Sync { super }
  end
end
Minitest::Test.prepend(AsyncTestRunner)

# Mock Session for unit tests (replaces the inbound librevox session)
module Switest
  class MockSession
      attr_reader :commands_sent

      def initialize
        @commands_sent = []
      end

      def send_message(msg)
        @commands_sent << msg
        mock_response
      end

      def execute_app(app, uuid, args = nil, **params)
        headers = {
          event_lock:       true,
          call_command:     "execute",
          execute_app_name: app,
          execute_app_arg:  args,
        }.merge(params)
          .map { |key, value| "#{key.to_s.tr('_', '-')}: #{value}" }

        @commands_sent << "sendmsg #{uuid}\n#{headers.join("\n")}"
        mock_response
      end

      def bgapi(cmd)
        send_message("bgapi #{cmd}")
      end

      private

      def mock_response
        Struct.new(:headers, :content, :event?, :event, :reply?).new(
          { reply_text: "+OK" },
          "+OK",
          false,
          nil,
          true
        )
      end
  end
end
