# frozen_string_literal: true

require "securerandom"
require_relative "from_parser"

module Switest
  module ESL
    class Client
      attr_reader :connection, :calls

      def initialize(connection = nil)
        @connection = connection
        @calls = {}
        @offer_handlers = []
      end

      def start
        @connection ||= Connection.new(
          host: Switest.configuration.host,
          port: Switest.configuration.port,
          password: Switest.configuration.password
        )
        @connection.connect

        # Register event handler with connection
        @connection.on_event { |response| handle_response(response) }

        self
      end

      def stop
        hangup_all
        @connection&.disconnect

        # Any remaining calls are orphaned - just clear them
        @calls.clear
      end

      # Hangup all active calls individually and wait for them to end.
      # Sends all hangups first, then waits with a shared deadline to avoid
      # O(n * timeout) delays with many calls.
      def hangup_all(cause: "NORMAL_CLEARING", timeout: 5)
        return unless @connection&.connected?

        active = @calls.values.reject(&:ended?)

        # Send all hangups without waiting
        active.each do |call|
          call.hangup(cause, wait: false) rescue nil
        end

        # Wait for all to end with a single shared deadline
        deadline = Time.now + timeout
        active.each do |call|
          remaining = deadline - Time.now
          break if remaining <= 0
          call.wait_for_end(timeout: remaining) unless call.ended?
        end
      end

      def dial(to:, from: nil, timeout: nil, headers: {})
        uuid = SecureRandom.uuid

        # Build channel variables
        vars = {
          origination_uuid: uuid,
          return_ring_ready: true
        }
        vars.merge!(FromParser.parse(from)) if from
        vars[:originate_timeout] = timeout if timeout

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
        rescue
          @calls.delete(uuid)
          raise
        end

        call
      end

      def on_offer(&block)
        @offer_handlers << block
      end

      def active_calls
        @calls.select { |_k, v| v.alive? }
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
        when "CHANNEL_BRIDGE"
          handle_channel_bridge(event)
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

      def handle_channel_bridge(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        other_uuid = event["Other-Leg-Unique-ID"]
        call ||= @calls[other_uuid] if other_uuid
        call&.handle_bridge
      end

      def handle_channel_hangup(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        other_uuid = event["Other-Leg-Unique-ID"]
        # For loopback calls, also check the other leg's UUID
        call ||= @calls[other_uuid] if other_uuid
        return unless call

        call.handle_hangup(event.hangup_cause, event.headers)
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
        @offer_handlers.each { |h| h.call(call) }
      end
    end
  end
end
