# frozen_string_literal: true

require_relative "rayo/stanzas"
require_relative "rayo/call"
require_relative "rayo/client"

module Switest
  # Manages the Rayo connection lifecycle.
  # Replaces the old Adhearsion integration.
  class Connection
    attr_reader :client

    def initialize(config = {})
      @config = Switest.configuration.to_h.merge(config)
      @client = nil
      @started = false
    end

    def start
      start! unless @started
    end

    def start!
      @client = Rayo::Client.new(
        host: @config[:host],
        port: @config[:port],
        username: @config[:username],
        password: @config[:password],
        logger: Switest.logger
      )

      @client.on_offer do |call|
        Switest.events.trigger(:inbound_call, call)
      end

      @client.connect
      @started = true

      at_exit { stop }

      true
    end

    def cleanup
      return unless @client

      @client.active_calls.each_value do |call|
        next unless call.alive?

        begin
          call.hangup
          call.wait_for_end(timeout: 3)
        rescue StandardError => e
          Switest.logger&.debug("Error hanging up call: #{e.message}")
        end
      end
    end

    def stop
      return unless @client

      cleanup
      @client.disconnect
      @client = nil
      @started = false
    end

    def started?
      @started
    end
  end
end
