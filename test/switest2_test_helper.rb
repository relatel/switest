# frozen_string_literal: true

$LOAD_PATH.unshift("lib")

require "bundler/setup" if defined?(Bundler)
require "minitest"
require "timeout"
require "switest2"

# Mock ESL Connection for unit tests
module Switest2
  module ESL
    class MockConnection
      attr_reader :commands_sent

      def initialize
        @commands_sent = []
        @connected = true
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
    end
  end
end
