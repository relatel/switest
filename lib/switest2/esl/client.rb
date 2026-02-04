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
        @running = false
        @reader_thread = nil
      end

      def start
        @connection ||= Connection.new(
          host: Switest2.configuration.host,
          port: Switest2.configuration.port,
          password: Switest2.configuration.password
        )
        @connection.connect
        @running = true
        @reader_thread = Thread.new { event_reader_loop }
        self
      end

      def stop
        @running = false
        @reader_thread&.join(2)
        @calls.each_value(&:hangup)
        @calls.clear
        @connection&.disconnect
      end

      def dial(to:, from: nil, headers: {})
        uuid = SecureRandom.uuid

        # Build originate string
        vars = ["origination_uuid=#{uuid}"]
        vars << "origination_caller_id_number=#{from}" if from
        headers.each { |k, v| vars << "#{k}=#{v}" }

        var_string = "{#{vars.join(",")}}"

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

      def event_reader_loop
        while @running && @connection.connected?
          begin
            response = @connection.read_event
            next unless response && response[:body]

            event = Event.parse(response[:body])
            next unless event

            handle_event(event)
          rescue Switest2::ConnectionError => e
            break unless @running
          rescue => e
            # Log and continue
            $stderr.puts "Event reader error: #{e.message}" if Switest2.configuration.log_level == :debug
          end
        end
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
        call&.handle_answer
      end

      def handle_channel_hangup(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        return unless call

        cause = event.hangup_cause
        call.handle_hangup(cause)

        # Keep call in map for a bit so assertions can check it
        # It will be cleaned up on next test
      end

      def handle_dtmf(event)
        uuid = event.uuid
        return unless uuid

        call = @calls[uuid]
        digit = event["DTMF-Digit"]
        call&.handle_dtmf(digit) if digit
      end

      def fire_offer(call)
        handlers = @mutex.synchronize { @offer_handlers.dup }
        handlers.each { |h| h.call(call) }
      end
    end
  end
end
