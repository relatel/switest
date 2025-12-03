# frozen_string_literal: true

module Switest
  module ESL
    # Parses ESL protocol messages.
    #
    # ESL uses HTTP-style framing:
    #   - Headers are "Key: Value" pairs, one per line
    #   - Headers end with a blank line
    #   - Body length is determined by Content-Length header
    #   - Header values are URL-encoded (percent encoding, NOT + for space)
    #
    # For text/event-plain, there's a two-level structure:
    #   Level 1 (packet): Content-Type: text/event-plain, Content-Length: N
    #   Level 2 (event):  Packet body contains event headers (+ optional event body)
    #
    # @example
    #   parser = Parser.new
    #   headers = parser.parse_headers("Event-Name: HEARTBEAT\nCore-UUID: abc123")
    #
    class Parser
      # Parse headers from a raw string.
      #
      # @param raw [String] Raw header text with "Key: Value" lines
      # @return [Hash<String, String>] Parsed headers with URL-decoded values
      def parse_headers(raw)
        headers = {}

        raw.each_line do |line|
          line = line.chomp
          break if line.empty?

          next unless line.include?(": ")

          key, value = line.split(": ", 2)
          headers[key] = decode_value(value.to_s)
        end

        headers
      end

      # Parse a complete ESL message (headers + optional body).
      #
      # @param raw [String] Raw message text
      # @return [Hash, nil] Hash with :headers and :body keys, or nil if empty
      def parse_message(raw)
        return nil if raw.nil? || raw.empty?

        header_section, body_section = raw.split("\n\n", 2)
        headers = parse_headers(header_section)

        return nil if headers.empty?

        body = extract_body(headers, body_section)

        { headers: headers, body: body }
      end

      # Parse the body of a text/event-plain packet (second-level parsing).
      #
      # @param body [String] Packet body containing event headers
      # @return [Array(Hash, String)] Tuple of [event_headers, event_body]
      def parse_event_plain(body)
        return [{}, nil] if body.nil? || body.empty?

        header_section, remaining = body.split("\n\n", 2)
        event_headers = parse_headers(header_section)
        event_body = extract_body(event_headers, remaining)

        [event_headers, event_body]
      end

      # Build an Event from a parsed message.
      #
      # @param headers [Hash] Packet headers
      # @param body [String, nil] Packet body
      # @return [Event]
      def build_event(headers:, body:)
        if headers["Content-Type"] == "text/event-plain" && body
          event_headers, event_body = parse_event_plain(body)
          Event.new(
            name: event_headers["Event-Name"],
            headers: event_headers,
            body: event_body
          )
        else
          Event.new(
            name: headers["Content-Type"],
            headers: headers,
            body: body
          )
        end
      end

      private

      # Extract body based on Content-Length header.
      #
      # @param headers [Hash] Headers containing Content-Length
      # @param body_section [String, nil] Raw body section
      # @return [String, nil]
      def extract_body(headers, body_section)
        return nil unless headers["Content-Length"]

        length = headers["Content-Length"].to_i
        return nil unless length.positive? && body_section

        body_section[0, length]
      end

      # Decode ESL header value (percent encoding only, + stays as +).
      # ESL uses URL encoding but does NOT encode space as +.
      #
      # @param value [String] URL-encoded value
      # @return [String] Decoded value
      def decode_value(value)
        value.gsub(/%([0-9A-Fa-f]{2})/) { [$1.hex].pack("C") }
      end
    end
  end
end
