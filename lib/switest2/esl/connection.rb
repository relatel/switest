# frozen_string_literal: true

require "socket"

module Switest2
  module ESL
    class Connection
      attr_reader :host, :port

      def initialize(host:, port:, password:)
        @host = host
        @port = port
        @password = password
        @socket = nil
        @mutex = Mutex.new
      end

      def connect
        @socket = TCPSocket.new(@host, @port)
        authenticate
        subscribe_events
        self
      end

      def disconnect
        @mutex.synchronize do
          if @socket
            @socket.close rescue nil
            @socket = nil
          end
        end
      end

      def connected?
        @socket && !@socket.closed?
      end

      def send_command(cmd)
        @mutex.synchronize do
          raise Switest2::ConnectionError, "Not connected" unless connected?
          @socket.write("#{cmd}\n\n")
          read_response
        end
      end

      def read_event
        # This should NOT be synchronized - it's called from dedicated reader thread
        raise Switest2::ConnectionError, "Not connected" unless connected?
        read_response
      end

      def api(cmd)
        response = send_command("api #{cmd}")
        body = response[:body] || ""
        if body.start_with?("-ERR")
          raise Switest2::Error, body
        end
        body
      end

      def bgapi(cmd)
        send_command("bgapi #{cmd}")
      end

      private

      def authenticate
        # Read auth request
        response = read_response
        unless response[:headers]["Content-Type"] == "auth/request"
          raise Switest2::AuthenticationError, "Expected auth/request, got: #{response[:headers]["Content-Type"]}"
        end

        # Send password
        @socket.write("auth #{@password}\n\n")

        # Read reply
        response = read_response
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise Switest2::AuthenticationError, "Authentication failed: #{reply}"
        end
      end

      def subscribe_events
        events = %w[
          CHANNEL_CREATE CHANNEL_ANSWER CHANNEL_HANGUP CHANNEL_HANGUP_COMPLETE
          CHANNEL_EXECUTE_COMPLETE DTMF CHANNEL_STATE
        ].join(" ")

        response = send_command("event plain #{events}")
        reply = response[:headers]["Reply-Text"] || ""
        unless reply.start_with?("+OK")
          raise Switest2::Error, "Failed to subscribe to events: #{reply}"
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
          raise Switest2::ConnectionError, "Connection closed" if line.nil?
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
