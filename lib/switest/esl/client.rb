# frozen_string_literal: true

require "concurrent"
require "securerandom"

module Switest
  module ESL
    # High-level ESL client that manages calls.
    class Client
      attr_reader :active_calls

      def initialize(host:, port: 8021, password: "ClueCon", logger: nil)
        @connection = Connection.new(host: host, port: port, password: password, logger: logger)
        @active_calls = Concurrent::Map.new
        @offer_callbacks = Concurrent::Array.new
        @logger = logger
      end

      def connect
        @connection.connect

        # Subscribe to relevant events
        @connection.subscribe_events(
          "CHANNEL_CREATE",
          "CHANNEL_ANSWER",
          "CHANNEL_HANGUP",
          "CHANNEL_HANGUP_COMPLETE",
          "CHANNEL_EXECUTE_COMPLETE",
          "CHANNEL_ORIGINATE"
        )

        # Set up event routing
        @connection.on_event do |event|
          route_event(event)
        end
      end

      def disconnect
        @connection.disconnect
        @active_calls.clear
      end

      def connected?
        @connection.connected?
      end

      # Dial an outbound call
      # @param to [String] Destination (e.g., "sofia/gateway/gw/+1234567890")
      # @param from [String, nil] Caller ID
      # @param headers [Hash] Additional headers/variables
      # @return [Call]
      def dial(to:, from: nil, headers: {})
        uuid = SecureRandom.uuid

        # Build originate command with variables
        vars = []
        vars << "origination_uuid=#{uuid}"
        vars << "origination_caller_id_number=#{from}" if from

        headers.each do |key, value|
          vars << "#{key}=#{value}"
        end

        var_string = vars.empty? ? "" : "{#{vars.join(",")}}"

        # Use bgapi for non-blocking originate, park the call
        @connection.bgapi("originate #{var_string}#{to} &park")

        # Create call object
        call = Call.new(@connection, uuid: uuid, to: to, from: from, headers: headers)
        @active_calls[uuid] = call

        call
      end

      # Register a callback for inbound call offers
      def on_offer(&block)
        @offer_callbacks << block
      end

      private

      def route_event(event)
        uuid = event.uuid
        return unless uuid

        case event.name
        when "CHANNEL_CREATE"
          handle_channel_create(event)
        when "CHANNEL_ANSWER", "CHANNEL_HANGUP", "CHANNEL_HANGUP_COMPLETE", "CHANNEL_EXECUTE_COMPLETE"
          # Route to existing call
          call = @active_calls[uuid]
          call&.handle_event(event)

          # Clean up ended calls
          if event.name == "CHANNEL_HANGUP_COMPLETE"
            @active_calls.delete(uuid)
          end
        end
      end

      def handle_channel_create(event)
        uuid = event.uuid
        return if @active_calls[uuid] # Already tracking this call

        # Only handle inbound calls
        return unless event.inbound?

        # Create call object for inbound call
        call = Call.new(
          @connection,
          uuid: uuid,
          to: event.destination,
          from: event.caller_id,
          headers: extract_headers(event)
        )

        @active_calls[uuid] = call

        # Notify offer callbacks
        @offer_callbacks.each do |callback|
          callback.call(call)
        rescue StandardError => e
          log(:error, "Offer callback error: #{e.message}")
        end
      end

      def extract_headers(event)
        # Extract SIP headers and channel variables
        headers = {}
        event.headers.each do |key, value|
          if key.start_with?("variable_sip_h_") || key.start_with?("variable_")
            # Remove prefix and add to headers
            clean_key = key.sub(/^variable_(sip_h_)?/, "")
            headers[clean_key] = value
          end
        end
        headers
      end

      def log(level, message)
        return unless @logger

        @logger.send(level, "[ESL::Client] #{message}")
      end
    end
  end
end
