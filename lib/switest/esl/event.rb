# frozen_string_literal: true

require "uri"

module Switest
  module ESL
    # Parses and represents FreeSWITCH ESL events.
    # Events are received in plain text format with headers separated by newlines.
    class Event
      attr_reader :name, :headers, :body

      def initialize(name:, headers: {}, body: nil)
        @name = name
        @headers = headers
        @body = body
      end

      # Parse an ESL event from raw text
      # Format:
      #   Header-Name: Header-Value
      #   Another-Header: Another-Value
      #   Content-Length: 123
      #
      #   <body if Content-Length present>
      def self.parse(raw)
        return nil if raw.nil? || raw.empty?

        lines = raw.split("\n")
        headers = {}
        body = nil

        lines.each do |line|
          break if line.strip.empty?

          if line.include?(": ")
            key, value = line.split(": ", 2)
            # URL-decode header values (ESL uses URL encoding)
            headers[key] = URI.decode_www_form_component(value.to_s.strip)
          end
        end

        # Extract body if Content-Length is present
        if headers["Content-Length"]
          content_length = headers["Content-Length"].to_i
          if content_length > 0
            # Find the blank line and extract body after it
            blank_idx = raw.index("\n\n")
            body = raw[blank_idx + 2, content_length] if blank_idx
          end
        end

        event_name = headers["Event-Name"] || headers["Content-Type"]
        new(name: event_name, headers: headers, body: body)
      end

      # Channel UUID
      def uuid
        headers["Unique-ID"] || headers["Channel-Call-UUID"]
      end

      # Destination number (called number)
      def destination
        headers["Caller-Destination-Number"] || headers["variable_destination_number"]
      end

      # Caller ID number
      def caller_id
        headers["Caller-Caller-ID-Number"] || headers["variable_caller_id_number"]
      end

      # Call direction
      def direction
        headers["Call-Direction"] || headers["Caller-Direction"]
      end

      # Generic header access
      def [](header_name)
        headers[header_name]
      end

      # Get a channel variable (automatically prefixes with "variable_" if needed)
      def variable(name)
        headers["variable_#{name}"] || headers[name]
      end

      # Check if this is an inbound call event
      def inbound?
        direction == "inbound"
      end

      # Check if this is an outbound call event
      def outbound?
        direction == "outbound"
      end

      # Application that was executed (for CHANNEL_EXECUTE_COMPLETE)
      def application
        headers["Application"] || headers["variable_current_application"]
      end

      # Application response/data (for CHANNEL_EXECUTE_COMPLETE)
      def application_response
        headers["Application-Response"] || headers["variable_read_result"]
      end

      # Get DTMF digits from a read application result
      def dtmf_digits
        variable("read_result") || application_response
      end

      # Hangup cause
      def hangup_cause
        headers["Hangup-Cause"] || headers["variable_hangup_cause"]
      end

      def to_s
        "#<Switest::ESL::Event name=#{name.inspect} uuid=#{uuid.inspect}>"
      end

      def inspect
        to_s
      end
    end
  end
end
