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

      def command(msg)
        @commands_sent << msg
        mock_response
      end

      def bgapi(cmd)
        command("bgapi #{cmd}")
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
