# frozen_string_literal: true

Thread.abort_on_exception = true

require "logger"
require "switest/events"
require "switest/connection"
require "switest/agent"
require "switest/scenario"
require "switest/timer"

module Switest
  class << self
    attr_writer :logger

    # Get the Rayo connection (replaces adhearsion)
    def connection
      @connection ||= Connection.new
    end

    # Alias for backwards compatibility
    alias adhearsion connection

    # Get active calls from the connection
    def active_calls
      connection.client&.active_calls || {}
    end

    # Get the event bus
    def events
      @events ||= Events.new
    end

    # Get the logger
    def logger
      @logger ||= default_logger
    end

    # Reset state (for testing)
    def reset
      @events = nil
    end

    # Configure Switest
    def configure
      yield(configuration) if block_given?
    end

    def configuration
      @configuration ||= Configuration.new
    end

    private

    def default_logger
      logger = Logger.new($stdout)
      logger.level = Logger::DEBUG
      logger
    end
  end

  # Configuration holder
  class Configuration
    attr_accessor :host, :port, :password, :log_level

    def initialize
      @host = "127.0.0.1"
      @port = 8021
      @password = "ClueCon"
      @log_level = Logger::DEBUG
    end

    def to_h
      {
        host: @host,
        port: @port,
        password: @password
      }
    end
  end
end
