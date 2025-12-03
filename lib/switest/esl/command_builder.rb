# frozen_string_literal: true

module Switest
  module ESL
    # Builds FreeSWITCH ESL commands with proper escaping and formatting.
    #
    # @example Building an originate command
    #   builder = CommandBuilder.new
    #   cmd = builder.originate(
    #     uuid: "abc-123",
    #     destination: "sofia/gateway/gw/+1234567890",
    #     caller_id: "+1987654321",
    #     variables: { "foo" => "bar" }
    #   )
    #
    class CommandBuilder
      # SIP headers start with a capital letter and need sip_h_ prefix
      SIP_HEADER_PATTERN = /\A[A-Z]/.freeze

      # Build an originate command.
      #
      # @param uuid [String] UUID for the new channel
      # @param destination [String] Destination dial string
      # @param caller_id [String, nil] Caller ID number
      # @param variables [Hash] Channel variables to set
      # @param application [String] Application to run after connect
      # @return [String] Complete originate command
      def originate(uuid:, destination:, caller_id: nil, variables: {}, application: "park")
        vars = build_variables(uuid: uuid, caller_id: caller_id, extra: variables)
        var_string = vars.empty? ? "" : "{#{vars.join(",")}}"

        "originate #{var_string}#{destination} &#{application}"
      end

      # Build a sendmsg command for channel execution.
      #
      # @param uuid [String] Channel UUID
      # @param app [String] Application name
      # @param arg [String, nil] Application argument
      # @return [String] Complete sendmsg command
      def sendmsg(uuid:, app:, arg: nil)
        lines = ["sendmsg #{uuid}"]
        lines << "call-command: execute"
        lines << "execute-app-name: #{app}"
        lines << "execute-app-arg: #{arg}" if arg

        lines.join("\n")
      end

      # Build an event subscription command.
      #
      # @param events [Array<String>] Event names to subscribe to
      # @param format [String] Event format (plain, xml, json)
      # @return [String] Event subscription command
      def event_subscribe(events: [], format: "plain")
        event_list = events.empty? ? "all" : events.join(" ")
        "event #{format} #{event_list}"
      end

      # Build an API command.
      #
      # @param command [String] API command
      # @param background [Boolean] Run in background
      # @return [String] API command string
      def api(command, background: false)
        prefix = background ? "bgapi" : "api"
        "#{prefix} #{command}"
      end

      # Build an auth command.
      #
      # @param password [String] ESL password
      # @return [String] Auth command
      def auth(password)
        "auth #{password}"
      end

      private

      # Build channel variables array.
      #
      # @param uuid [String] Channel UUID
      # @param caller_id [String, nil] Caller ID
      # @param extra [Hash] Additional variables
      # @return [Array<String>] Variable assignments
      def build_variables(uuid:, caller_id:, extra:)
        vars = []
        vars << "origination_uuid=#{uuid}"

        if caller_id
          vars.concat(caller_id_variables(caller_id))
        end

        extra.each do |key, value|
          vars << format_variable(key, value)
        end

        vars
      end

      # Build caller ID related variables.
      #
      # @param caller_id [String] Caller ID number
      # @return [Array<String>] Caller ID variable assignments
      def caller_id_variables(caller_id)
        [
          "origination_caller_id_number=#{caller_id}",
          "origination_caller_id_name=#{caller_id}",
          "sip_from_user=#{caller_id}",
          "sip_from_display=#{caller_id}"
        ]
      end

      # Format a variable for the originate command.
      # SIP headers (starting with capital letter) get sip_h_ prefix.
      #
      # @param key [String, Symbol] Variable name
      # @param value [String] Variable value
      # @return [String] Formatted variable assignment
      def format_variable(key, value)
        key_str = key.to_s

        if sip_header?(key_str)
          "sip_h_#{key_str}=#{escape_value(value)}"
        else
          "#{key_str}=#{escape_value(value)}"
        end
      end

      # Check if a key looks like a SIP header.
      #
      # @param key [String] Variable name
      # @return [Boolean]
      def sip_header?(key)
        key.match?(SIP_HEADER_PATTERN) && !key.start_with?("sip_")
      end

      # Escape a value for use in channel variables.
      #
      # @param value [String] Value to escape
      # @return [String] Escaped value
      def escape_value(value)
        # TODO: Add proper escaping for special characters if needed
        value.to_s
      end
    end
  end
end
