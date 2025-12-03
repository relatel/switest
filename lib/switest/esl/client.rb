# frozen_string_literal: true

require "concurrent"
require "securerandom"

module Switest
  module ESL
    # High-level ESL client that manages calls.
    #
    # Provides a clean API for:
    #   - Connecting to FreeSWITCH
    #   - Dialing outbound calls
    #   - Handling inbound call offers
    #   - Tracking active calls
    #
    # @example
    #   client = Client.new(host: "localhost")
    #   client.connect
    #   client.on_offer { |call| call.answer }
    #   call = client.dial(to: "sofia/gateway/gw/+1234567890", from: "+1987654321")
    #   call.wait_for_answer
    #
    class Client
      include Concerns::Loggable

      attr_reader :active_calls

      # @param host [String] FreeSWITCH host
      # @param port [Integer] ESL port
      # @param password [String] ESL password
      # @param logger [Logger, nil] Logger instance
      def initialize(host:, port: Constants::Defaults::PORT, password: Constants::Defaults::PASSWORD, logger: nil)
        @connection = Connection.new(host: host, port: port, password: password, logger: logger)
        @command_builder = CommandBuilder.new
        @header_extractor = HeaderExtractor.new
        @active_calls = Concurrent::Map.new
        @offer_callbacks = Concurrent::Array.new
        @logger = logger
      end

      # Connect to FreeSWITCH and subscribe to events.
      #
      # @raise [ESL::ConnectionError] if connection fails
      # @raise [ESL::AuthError] if authentication fails
      def connect
        @connection.connect
        @connection.subscribe_events(*Constants::Events::DEFAULT_SUBSCRIPTIONS)
        @connection.on_event { |event| route_event(event) }
      end

      # Disconnect from FreeSWITCH and clear active calls.
      def disconnect
        @connection.disconnect
        @active_calls.clear
      end

      # @return [Boolean] true if connected
      def connected?
        @connection.connected?
      end

      # Dial an outbound call.
      #
      # @param to [String] Destination (e.g., "sofia/gateway/gw/+1234567890")
      # @param from [String, nil] Caller ID
      # @param headers [Hash] Additional headers/variables
      # @return [Call] The new call object
      def dial(to:, from: nil, headers: {})
        uuid = SecureRandom.uuid

        command = @command_builder.originate(
          uuid: uuid,
          destination: to,
          caller_id: from,
          variables: headers
        )

        @connection.bgapi(command)

        call = Call.new(@connection, uuid: uuid, to: to, from: from, headers: headers)
        @active_calls[uuid] = call

        call
      end

      # Register a callback for inbound call offers.
      #
      # @yield [Call] Called when an inbound call is offered
      def on_offer(&block)
        @offer_callbacks << block
      end

      private

      def route_event(event)
        uuid = event.uuid
        return unless uuid

        case event.name
        when Constants::Events::CHANNEL_CREATE
          handle_channel_create(event)
        when Constants::Events::CHANNEL_ANSWER,
             Constants::Events::CHANNEL_HANGUP,
             Constants::Events::CHANNEL_HANGUP_COMPLETE,
             Constants::Events::CHANNEL_EXECUTE_COMPLETE
          route_to_call(event, uuid)
        end
      end

      def route_to_call(event, uuid)
        call = @active_calls[uuid]
        call&.handle_event(event)

        # Clean up ended calls
        @active_calls.delete(uuid) if event.name == Constants::Events::CHANNEL_HANGUP_COMPLETE
      end

      def handle_channel_create(event)
        uuid = event.uuid
        return if @active_calls[uuid]

        call = Call.new(
          @connection,
          uuid: uuid,
          to: event.destination,
          from: event.caller_id,
          headers: @header_extractor.extract(event)
        )

        @active_calls[uuid] = call
        notify_offer_callbacks(call, event) if event.inbound?
      end

      def notify_offer_callbacks(call, event)
        @offer_callbacks.each do |callback|
          callback.call(call)
        rescue StandardError => e
          log(:error, "Offer callback error: #{e.message}")
        end
      end

      def log_prefix
        "ESL::Client"
      end
    end
  end
end
