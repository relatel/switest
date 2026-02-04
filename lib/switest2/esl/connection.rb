# frozen_string_literal: true

require "socket"
require "concurrent"

module Switest2
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
          raise Switest2::Error, "Command timed out: #{cmd}"
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
        raise Switest2::Error, body if body.start_with?("-ERR")
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
          CHANNEL_CREATE CHANNEL_ANSWER CHANNEL_HANGUP CHANNEL_HANGUP_COMPLETE
          CHANNEL_EXECUTE_COMPLETE DTMF CHANNEL_STATE
        ].join(" ")

        @socket.write("event plain #{events}\n\n")
        response = read_response
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise Switest2::Error, "Failed to subscribe to events: #{reply}"
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

            # Read and dispatch event
            response = read_response
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
            response = read_response
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
