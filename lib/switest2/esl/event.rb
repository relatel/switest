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
        self["Event-Name"]
      end

      def uuid
        self["Unique-ID"] || self["Channel-Call-UUID"]
      end

      def caller_id
        self["Caller-Caller-ID-Number"]
      end

      def destination
        self["Caller-Destination-Number"]
      end

      def call_direction
        self["Call-Direction"]
      end

      def hangup_cause
        self["Hangup-Cause"]
      end

      # Case-insensitive header lookup
      def [](key)
        # Try exact match first (fast path)
        return @headers[key] if @headers.key?(key)
        # Fall back to case-insensitive search
        key_downcase = key.downcase
        @headers.find { |k, _| k.downcase == key_downcase }&.last
      end

      def variable(name)
        self["variable_#{name}"]
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
