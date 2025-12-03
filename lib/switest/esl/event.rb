# frozen_string_literal: true

module Switest
  module ESL
    # Represents a FreeSWITCH ESL event.
    #
    # ESL messages use HTTP-style framing:
    #   - Headers are "Key: Value" pairs, one per line
    #   - Headers end with a blank line
    #   - Body length is determined by Content-Length header
    #   - Header values are URL-encoded (percent encoding, NOT + for space)
    #
    # For text/event-plain, there's a two-level structure:
    #   Level 1 (packet): Content-Type: text/event-plain, Content-Length: N
    #   Level 2 (event):  Packet body contains event headers (+ optional event body)
    #
    class Event
      attr_reader :name, :headers, :body

      def initialize(name:, headers: {}, body: nil)
        @name = name
        @headers = headers
        @body = body
      end

      # Parse headers from a string (used for both packet and event headers)
      # @param raw [String] Raw header text
      # @return [Hash] Parsed headers with URL-decoded values
      def self.parse_headers(raw)
        headers = {}
        raw.each_line do |line|
          line = line.chomp
          break if line.empty?

          if line.include?(": ")
            key, value = line.split(": ", 2)
            headers[key] = decode_value(value.to_s)
          end
        end
        headers
      end

      # Parse a complete ESL message (headers + optional body)
      # @param raw [String] Raw message text
      # @return [Event, nil]
      def self.parse(raw)
        return nil if raw.nil? || raw.empty?

        # Split headers from body
        header_section, body_section = raw.split("\n\n", 2)
        headers = parse_headers(header_section)

        return nil if headers.empty?

        # Extract body based on Content-Length
        body = nil
        if headers["Content-Length"]
          length = headers["Content-Length"].to_i
          body = body_section[0, length] if length > 0 && body_section
        end

        event_name = headers["Event-Name"] || headers["Content-Type"]
        new(name: event_name, headers: headers, body: body)
      end

      # Parse the body of a text/event-plain packet (second-level parsing)
      # @param body [String] Packet body containing event headers
      # @return [Array<Hash, String>] [event_headers, event_body]
      def self.parse_event_plain(body)
        return [{}, nil] if body.nil? || body.empty?

        # Split event headers from event body
        header_section, remaining = body.split("\n\n", 2)
        event_headers = parse_headers(header_section)

        # Extract event body if Content-Length present in event headers
        event_body = nil
        if event_headers["Content-Length"] && remaining
          length = event_headers["Content-Length"].to_i
          event_body = remaining[0, length] if length > 0
        end

        [event_headers, event_body]
      end

      # Decode ESL header value (percent encoding only, + stays as +)
      # ESL uses URL encoding but does NOT encode space as +
      def self.decode_value(value)
        value.gsub(/%([0-9A-Fa-f]{2})/) { [$1.hex].pack("C") }
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
