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

      # Common accessors (keys normalized to lowercase)
      def name
        @headers["event-name"]
      end

      def uuid
        @headers["unique-id"] || @headers["channel-call-uuid"]
      end

      def caller_id
        @headers["caller-caller-id-number"]
      end

      def destination
        @headers["caller-destination-number"]
      end

      def call_direction
        @headers["call-direction"]
      end

      def hangup_cause
        @headers["hangup-cause"]
      end

      def [](key)
        @headers[key.downcase]
      end

      def variable(name)
        @headers["variable_#{name.downcase}"]
      end

      private

      def parse_headers(raw_data)
        raw_data.each_line do |line|
          line = line.strip
          next if line.empty?

          key, value = line.split(": ", 2)
          next unless key && value

          # ESL uses percent-encoding (%XX) but NOT + for spaces
          # Normalize keys to lowercase for case-insensitive lookup
          @headers[key.downcase] = value.gsub(/%([0-9A-Fa-f]{2})/) { [$1.to_i(16)].pack("C") }
        end
      end
    end
  end
end
