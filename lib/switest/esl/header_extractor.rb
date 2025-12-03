# frozen_string_literal: true

module Switest
  module ESL
    # Extracts and normalizes headers from ESL events.
    #
    # Handles the conversion of FreeSWITCH variable names to clean header names:
    #   - variable_sip_h_X-Custom -> X-Custom
    #   - variable_foo -> foo
    #
    # Also maps common SIP headers to expected names for test assertions.
    #
    # @example
    #   extractor = HeaderExtractor.new
    #   headers = extractor.extract(event)
    #   headers["from"]      # => "<sip:+1234@...>"
    #   headers["diversion"] # => "<sip:+5678@...>"
    #
    class HeaderExtractor
      # Prefix for SIP headers in FreeSWITCH variables
      SIP_HEADER_PREFIX = "variable_sip_h_"

      # Prefix for channel variables in FreeSWITCH
      VARIABLE_PREFIX = "variable_"

      # Extract all headers from an event, including normalized versions.
      #
      # @param event [Event] ESL event to extract headers from
      # @return [Hash<String, String>] Extracted and normalized headers
      def extract(event)
        headers = {}

        extract_raw_headers(event, headers)
        extract_cleaned_headers(event, headers)
        map_common_headers(event, headers)

        headers
      end

      # Normalize header keys (downcase, replace - with _).
      #
      # @param headers [Hash] Headers to normalize
      # @return [Hash] Normalized headers
      def normalize_keys(headers)
        headers.transform_keys { |k| k.to_s.downcase.tr("-", "_") }
      end

      private

      # Extract raw headers as-is from the event.
      #
      # @param event [Event] ESL event
      # @param headers [Hash] Target hash to populate
      def extract_raw_headers(event, headers)
        event.headers.each do |key, value|
          headers[key] = value
        end
      end

      # Extract cleaned versions of variable headers.
      #
      # @param event [Event] ESL event
      # @param headers [Hash] Target hash to populate
      def extract_cleaned_headers(event, headers)
        event.headers.each do |key, value|
          clean_key = clean_header_key(key)
          headers[clean_key] = value if clean_key
        end
      end

      # Clean a header key by removing FreeSWITCH prefixes.
      #
      # @param key [String] Original header key
      # @return [String, nil] Cleaned key or nil if not a variable
      def clean_header_key(key)
        if key.start_with?(SIP_HEADER_PREFIX)
          key.sub(SIP_HEADER_PREFIX, "")
        elsif key.start_with?(VARIABLE_PREFIX)
          key.sub(VARIABLE_PREFIX, "")
        end
      end

      # Map common SIP headers to expected names.
      #
      # @param event [Event] ESL event
      # @param headers [Hash] Target hash to populate
      def map_common_headers(event, headers)
        # SIP From header
        headers["from"] ||= event.variable("sip_full_from") ||
                           event.variable("sip_from_uri")

        # SIP Diversion header
        headers["diversion"] ||= event.variable("sip_h_Diversion")

        # SIP Remote-Party-ID
        headers["remote_party_id"] ||= event.variable("sip_h_Remote-Party-ID")

        # SIP P-Asserted-Identity
        headers["p_asserted_identity"] ||= event.variable("sip_h_P-Asserted-Identity")
      end
    end
  end
end
