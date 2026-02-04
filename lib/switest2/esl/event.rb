# frozen_string_literal: true

require "uri"

module Switest2
  module ESL
    class Event
      attr_reader :headers

      def self.parse(raw_data)
        return nil if raw_data.nil? || raw_data.empty?
        new(raw_data)
      end

      def initialize(raw_data)
        @headers = {}
        parse_headers(raw_data)
      end

      # Common accessors
      def name
        @headers["Event-Name"]
      end

      def uuid
        @headers["Unique-ID"] || @headers["Channel-Call-UUID"]
      end

      def caller_id
        @headers["Caller-Caller-ID-Number"]
      end

      def destination
        @headers["Caller-Destination-Number"]
      end

      def call_direction
        @headers["Call-Direction"]
      end

      def hangup_cause
        @headers["Hangup-Cause"]
      end

      def [](key)
        @headers[key]
      end

      def variable(name)
        @headers["variable_#{name}"]
      end

      private

      def parse_headers(raw_data)
        raw_data.each_line do |line|
          line = line.strip
          next if line.empty?

          key, value = line.split(": ", 2)
          next unless key && value

          # ESL uses percent-encoding (%XX) but NOT + for spaces
          @headers[key] = value.gsub(/%([0-9A-Fa-f]{2})/) { [$1.to_i(16)].pack("C") }
        end
      end
    end
  end
end
