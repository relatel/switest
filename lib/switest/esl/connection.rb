# frozen_string_literal: true

require "socket"
require "timeout"
require "concurrent"

module Switest
  module ESL
    # Low-level TCP connection to FreeSWITCH Event Socket.
    #
    # Handles authentication, command sending, and event receiving.
    # Uses a background thread for reading events from the socket.
    #
    # @example
    #   conn = Connection.new(host: "localhost", port: 8021, password: "ClueCon")
    #   conn.connect
    #   conn.on_event { |event| puts event.name }
    #   conn.api("status")
    #   conn.disconnect
    #
    class Connection
      include Concerns::Loggable

      attr_reader :host, :port

      # @param host [String] FreeSWITCH host
      # @param port [Integer] ESL port (default: 8021)
      # @param password [String] ESL password
      # @param logger [Logger, nil] Logger instance
      def initialize(host:, port: Constants::Defaults::PORT, password: Constants::Defaults::PASSWORD, logger: nil)
        @host = host
        @port = port
        @password = password
        @logger = logger
        @parser = Parser.new
        @command_builder = CommandBuilder.new

        @socket = nil
        @connected = false
        @reader_thread = nil
        @event_callbacks = Concurrent::Array.new
        @response_queue = Queue.new
        @mutex = Mutex.new
        @shutdown = false
      end

      # Connect to FreeSWITCH and authenticate.
      #
      # @raise [ConnectionError] if connection fails
      # @raise [AuthError] if authentication fails
      def connect
        @mutex.synchronize do
          return if @connected

          establish_connection
          authenticate
          @connected = true
          @shutdown = false

          log(:info, "Connected and authenticated to FreeSWITCH")
          start_reader_thread
        end
      end

      # Disconnect from FreeSWITCH gracefully.
      def close
        @mutex.synchronize do
          return unless @connected

          @shutdown = true
          @connected = false
          stop_reader_thread
          close_socket

          log(:info, "Disconnected from FreeSWITCH")
        end
      end

      alias disconnect close

      # @return [Boolean] true if connected
      def connected?
        @connected && socket_open?
      end

      # Send a command and wait for response.
      #
      # @param command [String] ESL command
      # @param timeout [Integer] Timeout in seconds
      # @return [Event] Response event
      # @raise [DisconnectedError] if not connected
      # @raise [TimeoutError] if command times out
      def send_recv(command, timeout: Constants::Defaults::COMMAND_TIMEOUT)
        raise DisconnectedError, "Not connected" unless connected?

        @mutex.synchronize { send_raw("#{command}\n\n") }
        wait_for_response(command, timeout)
      end

      # Send a command without waiting for response.
      #
      # @param command [String] ESL command
      # @raise [DisconnectedError] if not connected
      def send_async(command)
        raise DisconnectedError, "Not connected" unless connected?

        @mutex.synchronize { send_raw("#{command}\n\n") }
      end

      # Subscribe to events.
      #
      # @param events [Array<String>] Event names to subscribe to
      # @return [Event] Response
      def subscribe_events(*events)
        command = @command_builder.event_subscribe(events: events)
        send_recv(command)
      end

      # Register an event callback.
      #
      # @yield [Event] Called for each received event
      def on_event(&block)
        @event_callbacks << block
      end

      # Send a message to a specific channel.
      #
      # @param uuid [String] Channel UUID
      # @param app [String] Application name
      # @param arg [String, nil] Application argument
      # @param async [Boolean] Send without waiting for response
      # @return [Event, nil] Response event or nil if async
      def sendmsg(uuid, app:, arg: nil, async: false)
        command = @command_builder.sendmsg(uuid: uuid, app: app, arg: arg)

        if async
          send_async(command)
          nil
        else
          send_recv(command)
        end
      end

      # Execute background API command.
      #
      # @param command [String] API command
      # @return [Event] Response
      def bgapi(command)
        send_recv(@command_builder.api(command, background: true))
      end

      # Execute synchronous API command.
      #
      # @param command [String] API command
      # @return [Event] Response
      def api(command)
        send_recv(@command_builder.api(command, background: false))
      end

      private

      def establish_connection
        @socket = TCPSocket.new(@host, @port)
        @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
        raise ConnectionError, "Failed to connect to #{@host}:#{@port}: #{e.message}"
      end

      def authenticate
        response = read_response
        unless response&.headers&.[]("Content-Type") == Constants::ContentTypes::AUTH_REQUEST
          raise ConnectionError, "Expected auth/request, got: #{response&.headers}"
        end

        send_raw("#{@command_builder.auth(@password)}\n\n")
        response = read_response

        unless response&.headers&.[]("Reply-Text")&.start_with?("+OK")
          raise AuthError, "Authentication failed: #{response&.headers&.[]('Reply-Text')}"
        end
      end

      def send_raw(data)
        @socket.write(data)
        @socket.flush
      end

      def read_response
        headers = read_headers
        return nil if headers.empty?

        body = read_body(headers)
        @parser.build_event(headers: headers, body: body)
      end

      def read_headers
        header_lines = []

        while (line = @socket.gets)
          line = line.chomp
          break if line.empty?

          header_lines << line
        end

        return {} if header_lines.empty?

        @parser.parse_headers(header_lines.join("\n"))
      end

      def read_body(headers)
        return nil unless headers["Content-Length"]

        length = headers["Content-Length"].to_i
        return nil unless length.positive?

        @socket.read(length)
      end

      def wait_for_response(command, timeout)
        Timeout.timeout(timeout) { @response_queue.pop }
      rescue Timeout::Error
        raise TimeoutError, "Command timed out: #{command}"
      end

      def start_reader_thread
        @reader_thread = Thread.new { reader_loop }
      end

      def stop_reader_thread
        return unless @reader_thread

        # Give the thread a chance to exit gracefully
        @reader_thread.join(1)
        @reader_thread.kill if @reader_thread.alive?
        @reader_thread = nil
      end

      def reader_loop
        until @shutdown
          break unless connected?

          process_next_event
        end
      rescue IOError, Errno::ECONNRESET => e
        log(:error, "Connection error: #{e.message}") unless @shutdown
      rescue StandardError => e
        log(:error, "Reader error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      end

      def process_next_event
        event = read_response
        return unless event

        route_response(event)
      end

      def route_response(event)
        if response_event?(event)
          @response_queue << event
        else
          dispatch_event(event)
        end
      end

      def response_event?(event)
        [Constants::ContentTypes::COMMAND_REPLY,
         Constants::ContentTypes::API_RESPONSE].include?(event.name)
      end

      def dispatch_event(event)
        @event_callbacks.each do |callback|
          callback.call(event)
        rescue StandardError => e
          log(:error, "Event callback error: #{e.message}")
        end
      end

      def close_socket
        @socket&.close
        @socket = nil
      end

      def socket_open?
        !@socket.nil? && !@socket.closed?
      end

      def log_prefix
        "ESL"
      end
    end
  end
end
