# frozen_string_literal: true

module Switest
  module ESL
    # Escapes values for use in FreeSWITCH channel variable strings.
    #
    # FreeSWITCH originate syntax: {var1=value1,var2=value2}endpoint
    #
    # Escaping rules (per FreeSWITCH documentation):
    # - Spaces: wrap value in single quotes
    # - Commas in regular vars: use ^^<delim> syntax (e.g., ^^:val1:val2)
    # - Commas in SIP headers (sip_h_*): escape with backslash (\,)
    # - Single quotes in quoted values: escape with backslash (\')
    #
    # @see https://developer.signalwire.com/freeswitch/FreeSWITCH-Explained/Dialplan/Channel-Variables_16352493/
    module Escaper
      module_function

      # Characters that require the value to be quoted
      QUOTE_CHARS = /['\s<>]/

      # Characters that are problematic in channel variable values
      COMMA = ","

      # Escape a value for use in a regular channel variable.
      #
      # @param value [String, nil] The value to escape
      # @return [String, nil] The escaped value
      #
      # @example Simple value (no escaping needed)
      #   escape_value("+4512345678")
      #   # => "+4512345678"
      #
      # @example Value with spaces (quoted)
      #   escape_value("John Doe")
      #   # => "'John Doe'"
      #
      # @example Value with commas (uses ^^ delimiter)
      #   escape_value("one,two,three")
      #   # => "^^:one:two:three"
      #
      def escape_value(value)
        return value if value.nil?

        str = value.to_s
        return str if str.empty?

        has_comma = str.include?(COMMA)
        needs_quotes = str.match?(QUOTE_CHARS)

        if has_comma
          # Use ^^<delimiter> syntax for values containing commas
          # Pick a delimiter that's not in the string
          delimiter = find_delimiter(str)
          "^^#{delimiter}#{str.gsub(COMMA, delimiter)}"
        elsif needs_quotes
          # Wrap in single quotes and escape any single quotes in the value
          "'" + str.gsub("'", "\\\\'") + "'"
        else
          str
        end
      end

      # Escape a value for use in a SIP header variable (sip_h_*, sip_rh_*, sip_ph_*).
      #
      # SIP headers use backslash escaping for commas instead of the ^^ syntax.
      #
      # @param value [String, nil] The value to escape
      # @return [String, nil] The escaped value
      #
      # @example Value with commas
      #   escape_header_value("one,two,three")
      #   # => "one\\,two\\,three"
      #
      # @example Value with spaces and commas
      #   escape_header_value("Hello, World")
      #   # => "'Hello\\, World'"
      #
      def escape_header_value(value)
        return value if value.nil?

        str = value.to_s
        return str if str.empty?

        # First, escape commas with backslash (SIP header specific)
        escaped = str.gsub(COMMA, "\\,")

        # Then check if we need quotes for other special chars
        if escaped.match?(QUOTE_CHARS)
          "'" + escaped.gsub("'", "\\\\'") + "'"
        else
          escaped
        end
      end

      # Build a channel variable string for originate command.
      #
      # @param vars [Hash] Variable name => value pairs
      # @param sip_header_vars [Hash] SIP header name => value pairs (will be prefixed with sip_h_)
      # @return [String] The formatted variable string, e.g., "{var1=val1,var2=val2}"
      #
      # @example
      #   build_var_string(
      #     { origination_uuid: "abc-123", origination_caller_id_name: "John Doe" },
      #     { "X-Custom" => "value,with,commas" }
      #   )
      #   # => "{origination_uuid=abc-123,origination_caller_id_name='John Doe',sip_h_X-Custom=value\\,with\\,commas}"
      #
      def build_var_string(vars = {}, sip_header_vars = {})
        vars ||= {}
        sip_header_vars ||= {}
        parts = []

        vars.each do |key, value|
          next if value.nil?
          parts << "#{key}=#{escape_value(value)}"
        end

        sip_header_vars.each do |key, value|
          next if value.nil?
          parts << "sip_h_#{key}=#{escape_header_value(value)}"
        end

        return "" if parts.empty?

        "{#{parts.join(",")}}"
      end

      # Find a delimiter character that's not present in the string.
      # Used for the ^^<delimiter> syntax.
      #
      # @param str [String] The string to check
      # @return [String] A single character delimiter
      def find_delimiter(str)
        # Try common delimiters in order of preference
        %w[: | # @ ! ~ ^ ; /].each do |delim|
          return delim unless str.include?(delim)
        end
        # Fallback - this should rarely happen
        ":"
      end
    end
  end
end
