# frozen_string_literal: true

require "socket"
require "concurrent"

module Switest
  module ESL
    # Thread-safe ESL connection.
    #
    # All socket I/O is handled by a single reader thread to avoid race conditions.
    # Commands are sent via a queue and responses are returned via promises.
    class Connection
      attr_reader :host, :port

      def initialize(host:, port:, password:)
        @host = host
        @port = port
        @password = password
        @socket = nil
        @running = false
        @reader_thread = nil
        @command_queue = Queue.new
        @event_handlers = []
        @mutex = Mutex.new
      end

      def connect
        @socket = TCPSocket.new(@host, @port)
        authenticate
        subscribe_events
        @running = true
        @reader_thread = Thread.new { reader_loop }
        self
      end

      def disconnect
        @running = false
        # Close socket to unblock any pending reads
        @mutex.synchronize do
          if @socket
            @socket.close rescue nil
            @socket = nil
          end
        end
        # Fail any pending commands
        until @command_queue.empty?
          item = @command_queue.pop(true) rescue nil
          item[:promise].fail(ConnectionError.new("Disconnected")) if item&.dig(:promise)
        end
        @reader_thread&.join(2)
        @reader_thread = nil
      end

      def connected?
        @running && @socket && !@socket.closed?
      end

      # Send a command and wait for response (thread-safe)
      def send_command(cmd, timeout: 5)
        raise ConnectionError, "Not connected" unless connected?

        promise = Concurrent::IVar.new
        @command_queue.push({ cmd: cmd, promise: promise })

        # Wait for response with timeout
        result = promise.value(timeout)
        if promise.pending?
          raise Switest::Error, "Command timed out: #{cmd}"
        elsif promise.rejected?
          raise promise.reason
        end
        result
      end

      # Register a handler for incoming events
      def on_event(&block)
        @mutex.synchronize { @event_handlers << block }
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
        # Read auth request (before reader thread starts)
        response = read_response
        unless response[:headers]["Content-Type"] == "auth/request"
          raise AuthenticationError, "Expected auth/request, got: #{response[:headers]["Content-Type"]}"
        end

        # Send password
        @socket.write("auth #{@password}\n\n")

        # Read reply
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
          CHANNEL_EXECUTE_COMPLETE # Wait for application execution to finish
          DTMF                     # Receive DTMF digits per call
        ].join(" ")

        @socket.write("event plain #{events}\n\n")
        response = read_response
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise Switest::Error, "Failed to subscribe to events: #{reply}"
        end
      end

      # Main reader loop - handles both commands and events
      def reader_loop
        while @running
          begin
            # Process any pending commands first
            process_pending_commands

            # Check for incoming data with short timeout (allows checking queue regularly)
            ready = IO.select([@socket], nil, nil, 0.1) rescue nil
            break unless @running && @socket && !@socket.closed?
            next unless ready

            # Read and dispatch event (skip orphaned command replies)
            response = read_response
            content_type = response[:headers]["Content-Type"]
            next if content_type == "command/reply" || content_type == "api/response"

            if content_type == "text/disconnect-notice"
              break
            end

            dispatch_event(response)
          rescue IOError, Errno::EBADF, Errno::ECONNRESET
            # Socket closed
            break
          rescue => e
            # Log but continue on other errors
            break unless @running
          end
        end
      end

      def process_pending_commands
        while @running && !@command_queue.empty?
          item = @command_queue.pop(true) rescue nil
          break unless item

          begin
            @socket.write("#{item[:cmd]}\n\n")
            response = read_command_response
            item[:promise].set(response)
          rescue => e
            item[:promise].fail(e)
          end
        end
      end

      def dispatch_event(response)
        handlers = @mutex.synchronize { @event_handlers.dup }
        handlers.each { |h| h.call(response) }
      end

      # Read responses until we get a command reply, dispatching any
      # interleaved events that arrive before the reply.
      def read_command_response
        loop do
          response = read_response
          content_type = response[:headers]["Content-Type"]

          case content_type
          when "command/reply", "api/response"
            return response
          when "text/event-plain"
            dispatch_event(response)
          when "text/disconnect-notice"
            raise ConnectionError, "Disconnected"
          else
            return response
          end
        end
      end

      def read_response
        headers = read_headers
        body = nil

        if (content_length = headers["Content-Length"]&.to_i) && content_length > 0
          body = @socket.read(content_length)
        end

        { headers: headers, body: body }
      end

      def read_headers
        headers = {}
        loop do
          line = @socket.gets
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
