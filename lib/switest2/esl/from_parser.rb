# frozen_string_literal: true

module Switest2
  module ESL
    # Parses a `from` string into FreeSWITCH channel variables,
    # replicating mod_rayo's parse_dial_from() behavior.
    #
    # Algorithm (matching mod_rayo):
    # 1. Split on last space — before = display name, after = URI
    # 2. No space — entire string is URI, no display name
    # 3. Strip "" from display name (if quoted)
    # 4. Strip <> from URI (if angle-bracketed)
    # 5. Detect scheme: sip:/sips: with @ → SIP, tel: → TEL, plain → TEL, empty → UNKNOWN
    # 6. Map to FreeSWITCH variables accordingly
    module FromParser
      module_function

      SIP_URI_PATTERN = /\Asips?:.+@/

      # Parse a from string into a hash of FreeSWITCH channel variable symbol keys.
      #
      # @param from [String, nil] The from string to parse
      # @return [Hash] Symbol keys matching channel variable names, only keys with values
      def parse(from)
        return {} if from.nil? || from.strip.empty?

        display_name, uri = split_display_and_uri(from)
        display_name = strip_quotes(display_name)
        uri = strip_angle_brackets(uri)

        return {} if uri.empty?

        if uri.match?(SIP_URI_PATTERN)
          build_sip_vars(display_name, uri)
        elsif uri.start_with?("tel:")
          number = uri.delete_prefix("tel:")
          build_tel_vars(display_name, number)
        else
          build_tel_vars(display_name, uri)
        end
      end

      # Split on last space: everything before = display name, after = URI.
      # If no space, entire string is URI with no display name.
      def split_display_and_uri(from)
        from = from.strip
        last_space = from.rindex(" ")

        if last_space
          [from[0...last_space], from[(last_space + 1)..]]
        else
          [nil, from]
        end
      end

      # Strip surrounding double-quotes from display name.
      def strip_quotes(name)
        return nil if name.nil?
        name = name.strip
        return nil if name.empty?

        if name.start_with?('"') && name.end_with?('"')
          name = name[1...-1]
        end

        name.empty? ? nil : name
      end

      # Strip surrounding angle brackets from URI.
      def strip_angle_brackets(uri)
        return "" if uri.nil?
        uri = uri.strip

        if uri.start_with?("<") && uri.end_with?(">")
          uri = uri[1...-1]
        end

        uri
      end

      def build_sip_vars(display_name, uri)
        vars = {
          sip_from_uri: uri,
          origination_caller_id_number: uri
        }

        if display_name
          vars[:sip_from_display] = display_name
          vars[:origination_caller_id_name] = display_name
        end

        vars
      end

      def build_tel_vars(display_name, number)
        vars = {
          origination_caller_id_number: number,
          origination_caller_id_name: display_name || number
        }

        vars
      end
    end
  end
end
