# frozen_string_literal: true

require "socket"
require "concurrent"

module Switest
  module ESL
    # Low-level TCP connection to FreeSWITCH Event Socket.
    # Handles authentication, command sending, and event receiving.
    class Connection
      attr_reader :host, :port

      def initialize(host:, port: 8021, password: "ClueCon", logger: nil)
        @host = host
        @port = port
        @password = password
        @logger = logger
        @socket = nil
        @connected = false
        @reader_thread = nil
        @event_callbacks = Concurrent::Array.new
        @response_queue = Queue.new
        @mutex = Mutex.new
      end

      # Connect to FreeSWITCH and authenticate
      def connect
        @mutex.synchronize do
          return if @connected

          log(:debug, "Connecting to #{@host}:#{@port}")
          @socket = TCPSocket.new(@host, @port)
          @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

          # Read auth/request
          response = read_response
          unless response&.headers&.[]("Content-Type") == "auth/request"
            raise ConnectionError, "Expected auth/request, got: #{response&.headers}"
          end

          # Send auth command
          send_raw("auth #{@password}\n\n")
          response = read_response

          unless response&.headers&.[]("Reply-Text")&.start_with?("+OK")
            raise AuthError, "Authentication failed: #{response&.headers&.[]('Reply-Text')}"
          end

          @connected = true
          log(:info, "Connected and authenticated to FreeSWITCH")

          # Start background reader thread
          start_reader_thread
        end
      end

      # Disconnect from FreeSWITCH
      def close
        @mutex.synchronize do
          return unless @connected

          @connected = false
          @reader_thread&.kill
          @reader_thread = nil
          @socket&.close
          @socket = nil
          log(:info, "Disconnected from FreeSWITCH")
        end
      end

      alias disconnect close

      def connected?
        @connected && !@socket.nil? && !@socket.closed?
      end

      # Send a command and wait for response
      def send_recv(command, timeout: 5)
        raise ConnectionError, "Not connected" unless connected?

        @mutex.synchronize do
          send_raw("#{command}\n\n")
        end

        # Wait for response from reader thread
        begin
          Timeout.timeout(timeout) do
            @response_queue.pop
          end
        rescue Timeout::Error
          raise TimeoutError, "Command timed out: #{command}"
        end
      end

      # Send a command without waiting for response
      def send_async(command)
        raise ConnectionError, "Not connected" unless connected?

        @mutex.synchronize do
          send_raw("#{command}\n\n")
        end
      end

      # Subscribe to events
      def subscribe_events(*events)
        event_list = events.empty? ? "all" : events.join(" ")
        send_recv("event plain #{event_list}")
      end

      # Register an event callback
      def on_event(&block)
        @event_callbacks << block
      end

      # Send a message to a specific channel (sendmsg)
      def sendmsg(uuid, app:, arg: nil, async: false)
        lines = ["sendmsg #{uuid}"]
        lines << "call-command: execute"
        lines << "execute-app-name: #{app}"
        lines << "execute-app-arg: #{arg}" if arg

        if async
          send_async(lines.join("\n"))
          nil
        else
          send_recv(lines.join("\n"))
        end
      end

      # Execute bgapi command (background API)
      def bgapi(command)
        send_recv("bgapi #{command}")
      end

      # Execute api command (synchronous)
      def api(command)
        send_recv("api #{command}")
      end

      private

      def send_raw(data)
        log(:debug, ">>> #{data.strip}")
        @socket.write(data)
        @socket.flush
      end

      def read_response
        headers = {}
        body = nil

        # Read headers until blank line
        while (line = @socket.gets)
          line = line.chomp
          break if line.empty?

          if line.include?(": ")
            key, value = line.split(": ", 2)
            headers[key] = URI.decode_www_form_component(value.to_s)
          end
        end

        return nil if headers.empty?

        # Read body if Content-Length present
        if headers["Content-Length"]
          content_length = headers["Content-Length"].to_i
          body = @socket.read(content_length) if content_length > 0
        end

        Event.new(name: headers["Content-Type"], headers: headers, body: body)
      end

      def start_reader_thread
        @reader_thread = Thread.new do
          loop do
            break unless connected?

            begin
              event = read_response
              next unless event

              log(:debug, "<<< #{event.name}: #{event.uuid}")

              # Route response to waiting command or to event callbacks
              if event.name == "command/reply" || event.name == "api/response"
                @response_queue << event
              else
                dispatch_event(event)
              end
            rescue IOError, Errno::ECONNRESET => e
              log(:error, "Connection error: #{e.message}")
              break
            rescue StandardError => e
              log(:error, "Reader error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
            end
          end
        end
      end

      def dispatch_event(event)
        @event_callbacks.each do |callback|
          callback.call(event)
        rescue StandardError => e
          log(:error, "Event callback error: #{e.message}")
        end
      end

      def log(level, message)
        return unless @logger

        @logger.send(level, "[ESL] #{message}")
      end
    end
  end
end
