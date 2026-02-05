# frozen_string_literal: true

require "securerandom"

module Switest2
  module ESL
    class Client
      attr_reader :connection, :calls

      def initialize(connection = nil)
        @connection = connection
        @calls = Concurrent::Map.new
        @offer_handlers = []
        @mutex = Mutex.new
      end

      def start
        @connection ||= Connection.new(
          host: Switest2.configuration.host,
          port: Switest2.configuration.port,
          password: Switest2.configuration.password
        )
        @connection.connect

        # Register event handler with connection
        @connection.on_event { |response| handle_response(response) }

        self
      end

      def stop
        # Hangup all active calls before disconnecting
        if @connection&.connected?
          @calls.each_value do |call|
            next if call.ended?
            begin
              call.hangup("NORMAL_CLEARING", wait: 2)
            rescue
              # Ignore errors during cleanup
            end
          end
        end

        @connection&.disconnect

        # Mark any remaining calls as ended locally
        @calls.each_value { |call| call.handle_hangup("SWITCH_SHUTDOWN") unless call.ended? }
        @calls.clear
      end

      def dial(to:, from: nil, headers: {})
        uuid = SecureRandom.uuid

        # Build channel variables
        vars = { origination_uuid: uuid }
        if from
          vars[:origination_caller_id_number] = from
          vars[:origination_caller_id_name] = from
        end

        var_string = Escaper.build_var_string(vars, headers)

        # Create call object before originate
        call = Call.new(
          id: uuid,
          connection: @connection,
          direction: :outbound,
          to: to,
          from: from,
          headers: headers
        )
        @calls[uuid] = call

        # Originate call (park it so we control it)
        begin
          @connection.bgapi("originate #{var_string}#{to} &park")
        rescue => e
          @calls.delete(uuid)
          raise
        end

        call
      end

      def on_offer(&block)
        @mutex.synchronize { @offer_handlers << block }
      end

      def active_calls
        result = {}
        @calls.each_pair { |k, v| result[k] = v if v.alive? }
        result
      end

      private

      def handle_response(response)
        return unless response && response[:body]

        event = Event.parse(response[:body])
        return unless event

        handle_event(event)
      end

      def handle_event(event)
        case event.name
        when "CHANNEL_CREATE"
          handle_channel_create(event)
        when "CHANNEL_ANSWER"
          handle_channel_answer(event)
        when "CHANNEL_HANGUP_COMPLETE"
          handle_channel_hangup(event)
        when "DTMF"
          handle_dtmf(event)
        end
      end

      def handle_channel_create(event)
        uuid = event.uuid
        return unless uuid

        # Skip if we already have this call (outbound call we created)
        return if @calls[uuid]

        # Only handle inbound calls
        direction = event.call_direction
        return unless direction == "inbound"

        call = Call.new(
          id: uuid,
          connection: @connection,
          direction: :inbound,
          to: event.destination,
          from: event.caller_id,
          headers: event.headers.dup
        )
        @calls[uuid] = call

        # Notify offer handlers
        fire_offer(call)
      end

      def handle_channel_answer(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        other_uuid = event["Other-Leg-Unique-ID"]
        # For loopback calls, also check the other leg's UUID
        call ||= @calls[other_uuid] if other_uuid
        call&.handle_answer
      end

      def handle_channel_hangup(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        other_uuid = event["Other-Leg-Unique-ID"]
        # For loopback calls, also check the other leg's UUID
        call ||= @calls[other_uuid] if other_uuid
        return unless call

        cause = event.hangup_cause
        call.handle_hangup(cause)
      end

      def handle_dtmf(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        other_uuid = event["Other-Leg-Unique-ID"]
        # For loopback calls, also check the other leg's UUID
        call ||= @calls[other_uuid] if other_uuid
        return unless call

        digit = event["DTMF-Digit"]
        call.handle_dtmf(digit) if digit
      end

      def fire_offer(call)
        handlers = @mutex.synchronize { @offer_handlers.dup }
        handlers.each { |h| h.call(call) }
      end
    end
  end
end
