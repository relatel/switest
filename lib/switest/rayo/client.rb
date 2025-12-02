# frozen_string_literal: true

# Require blather/client/dsl instead of blather/client to avoid the CLI parser
require "blather/client/dsl"
require "concurrent"

module Switest
  module Rayo
    # XMPP client for Rayo protocol communication with FreeSWITCH.
    # Uses Blather for XMPP and EventMachine for async I/O.
    class Client
      attr_reader :active_calls

      def initialize(host:, port: 5222, username:, password:, logger: nil)
        @host = host
        @port = port
        @username = username
        @password = password
        @logger = logger

        @jid = Blather::JID.new("#{username}")
        @blather = nil
        @active_calls = Concurrent::Map.new
        @offer_callbacks = Concurrent::Array.new
        @connected = Concurrent::Event.new
        @em_thread = nil
        @mutex = Mutex.new
      end

      # Connect to the Rayo server
      def connect
        @mutex.synchronize do
          return if @blather

          setup_blather
          start_event_machine
          @connected.wait(10)
        end
      end

      # Disconnect from the server
      def disconnect
        @mutex.synchronize do
          return unless @blather

          @blather.close if @blather.connected?
          stop_event_machine
          @blather = nil
          @connected.reset
        end
      end

      def connected?
        @blather&.connected? || false
      end

      # Dial an outbound call
      # Returns a Call object
      def dial(to:, from: nil, headers: {})
        raise ClientError, "Not connected" unless connected?

        dial_cmd = Dial.new(to, from, headers)
        response = send_command_sync(dial_cmd)

        # The response contains a ref with the call URI
        ref_node = response.find_first("//ns:ref", ns: RAYO_NS)
        raise ClientError, "No ref in dial response" unless ref_node

        call_uri = ref_node["uri"] || ref_node["id"]
        call_jid = Blather::JID.new(call_uri)

        call = Call.new(self, jid: call_jid, to: to, from: from, headers: headers)
        @active_calls[call.id] = call
        call
      end

      # Register a callback for inbound call offers
      def on_offer(&block)
        @offer_callbacks << block
      end

      # Send a command (async, no response expected)
      def send_command(command)
        raise ClientError, "Not connected" unless connected?

        @blather.write_to_stream(command)
      end

      # Send a command and wait for response
      def send_command_sync(command, timeout: 5)
        raise ClientError, "Not connected" unless connected?

        response_event = Concurrent::Event.new
        response_stanza = nil

        # Register a one-time handler for this IQ
        handler_id = @blather.register_handler(:iq, id: command.id) do |iq|
          response_stanza = iq
          response_event.set
        end

        @blather.write_to_stream(command)

        unless response_event.wait(timeout)
          raise ClientError, "Timeout waiting for command response"
        end

        if response_stanza.type == :error
          error_node = response_stanza.find_first("//error")
          error_text = error_node&.text || "Unknown error"
          raise ClientError, "Command error: #{error_text}"
        end

        response_stanza
      end

      private

      def setup_blather
        @blather = Blather::Client.new
        @blather.setup(@jid.to_s, @password, @host, @port)

        # Connection established
        @blather.register_handler(:ready) do
          log(:info, "Connected to Rayo server")
          @connected.set
        end

        # Connection lost
        @blather.register_handler(:disconnected) do
          log(:warn, "Disconnected from Rayo server")
          @connected.reset
        end

        # Handle offer presence (inbound calls)
        @blather.register_handler(:presence, "/presence/ns:offer", ns: RAYO_NS) do |presence|
          handle_offer(presence)
        end

        # Handle answered presence
        @blather.register_handler(:presence, "/presence/ns:answered", ns: RAYO_NS) do |presence|
          handle_answered(presence)
        end

        # Handle ringing presence
        @blather.register_handler(:presence, "/presence/ns:ringing", ns: RAYO_NS) do |presence|
          handle_ringing(presence)
        end

        # Handle end presence
        @blather.register_handler(:presence, "/presence/ns:end", ns: RAYO_NS) do |presence|
          handle_end(presence)
        end

        # Handle errors
        @blather.register_handler(:stream_error) do |error|
          log(:error, "Stream error: #{error}")
        end
      end

      def start_event_machine
        @em_thread = Thread.new do
          EM.run do
            @blather.run
          end
        end
      end

      def stop_event_machine
        return unless @em_thread

        EM.stop if EM.reactor_running?
        @em_thread.join(5)
        @em_thread = nil
      end

      def handle_offer(presence)
        offer = Offer.new
        offer.inherit(presence)

        call = Call.from_offer(self, offer)
        @active_calls[call.id] = call

        log(:debug, "Received offer for call #{call.id}")
        @offer_callbacks.each { |cb| cb.call(call) }
      end

      def handle_answered(presence)
        call_id = presence.from.node
        call = @active_calls[call_id]
        return unless call

        log(:debug, "Call #{call_id} answered")
        call.handle_answered
      end

      def handle_ringing(presence)
        call_id = presence.from.node
        log(:debug, "Call #{call_id} ringing")
        # Ringing is informational, no state change needed
      end

      def handle_end(presence)
        call_id = presence.from.node
        call = @active_calls[call_id]
        return unless call

        # Parse the reason from the end stanza
        end_node = presence.find_first("//ns:end", ns: RAYO_NS)
        reason = parse_end_reason(end_node)

        log(:debug, "Call #{call_id} ended: #{reason}")
        call.handle_end(reason)
        @active_calls.delete(call_id)
      end

      def parse_end_reason(end_node)
        return :unknown unless end_node

        Rayo::End::REASONS.each do |r|
          reason_str = r.to_s.tr("_", "-")
          return r if end_node.xpath("ns:#{reason_str}", ns: RAYO_NS).any?
        end
        :unknown
      end

      def log(level, message)
        return unless @logger

        @logger.send(level, "[Rayo] #{message}")
      end
    end

    class ClientError < StandardError; end
  end
end
