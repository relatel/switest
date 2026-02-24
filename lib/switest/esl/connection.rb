# frozen_string_literal: true

require "io/endpoint/host_endpoint"
require "io/stream"
require "async"
require "async/condition"

module Switest
  module ESL
    # Async ESL connection.
    #
    # All socket reads are handled by a single reader task. Commands are written
    # directly and responses are delivered via conditions (fiber-safe signals).
    class Connection
      attr_reader :host, :port

      def initialize(host:, port:, password:)
        @host = host
        @port = port
        @password = password
        @endpoint = IO::Endpoint.tcp(host, port)
        @socket = nil
        @stream = nil
        @running = false
        @reader_task = nil
        @pending_responses = []
        @event_handlers = []
      end

      def connect
        @socket = @endpoint.connect
        @stream = IO::Stream::Buffered.wrap(@socket)
        authenticate
        subscribe_events
        @running = true
        @reader_task = Async { reader_loop }
        self
      end

      def disconnect
        @running = false
        @reader_task&.stop
        @reader_task = nil
        @stream&.close rescue nil
        @stream = nil
        @socket = nil
        @pending_responses.each { |c| c.signal(nil) }
        @pending_responses.clear
      end

      def connected?
        @running && @stream && !@stream.closed?
      end

      def send_command(cmd, timeout: 5)
        raise ConnectionError, "Not connected" unless connected?

        condition = Async::Condition.new
        @pending_responses << condition

        @stream.write("#{cmd}\n\n")
        @stream.flush

        Async::Task.current.with_timeout(timeout) do
          response = condition.wait
          raise ConnectionError, "Disconnected" if response.nil?
          response
        end
      rescue Async::TimeoutError
        @pending_responses.delete(condition)
        raise Switest::Error, "Command timed out: #{cmd}"
      end

      def on_event(&block)
        @event_handlers << block
      end

      def api(cmd)
        response = send_command("api #{cmd}")
        body = response[:body] || ""
        raise Switest::Error, body if body.start_with?("-ERR")
        body
      end

      def bgapi(cmd)
        send_command("bgapi #{cmd}")
      end

      private

      def authenticate
        response = read_response
        unless response[:headers]["Content-Type"] == "auth/request"
          raise AuthenticationError, "Expected auth/request, got: #{response[:headers]["Content-Type"]}"
        end

        @stream.write("auth #{@password}\n\n")
        @stream.flush

        response = read_response
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise AuthenticationError, "Authentication failed: #{reply}"
        end
      end

      def subscribe_events
        events = %w[
          CHANNEL_CREATE           # Detect new inbound calls
          CHANNEL_ANSWER           # Track when calls are answered
          CHANNEL_BRIDGE           # Track when calls are bridged
          CHANNEL_HANGUP_COMPLETE  # Track call end with final headers
          DTMF                     # Receive DTMF digits per call
        ].join(" ")

        @stream.write("event plain #{events}\n\n")
        @stream.flush
        response = read_response
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise Switest::Error, "Failed to subscribe to events: #{reply}"
        end
      end

      def reader_loop
        while @running
          response = read_response
          content_type = response[:headers]["Content-Type"]

          case content_type
          when "command/reply", "api/response"
            condition = @pending_responses.shift
            condition&.signal(response)
          when "text/disconnect-notice"
            break
          when "text/event-plain"
            dispatch_event(response)
          end
        end
      rescue IOError, Errno::EBADF, Errno::ECONNRESET, ConnectionError
        # Socket closed
      ensure
        @running = false
        # Wake any fibers waiting on a command response
        @pending_responses.each { |c| c.signal(nil) }
        @pending_responses.clear
      end

      def dispatch_event(response)
        @event_handlers.each { |h| h.call(response) }
      end

      def read_response
        headers = read_headers
        body = nil

        if (content_length = headers["Content-Length"]&.to_i) && content_length > 0
          body = @stream.read_exactly(content_length)
        end

        { headers: headers, body: body }
      end

      def read_headers
        headers = {}
        loop do
          line = @stream.gets("\n")
          raise ConnectionError, "Connection closed" if line.nil?
          line = line.chomp
          break if line.empty?

          key, value = line.split(": ", 2)
          headers[key] = value if key && value
        end
        headers
      end
    end
  end
end
