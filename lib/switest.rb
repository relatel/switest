# frozen_string_literal: true

Thread.abort_on_exception = true

require "logger"

# Core utilities
require "switest/constants"
require "switest/errors"
require "switest/concerns/loggable"
require "switest/condition_matcher"

# ESL layer
require "switest/esl/parser"
require "switest/esl/command_builder"
require "switest/esl/header_extractor"
require "switest/esl/event"
require "switest/esl/connection"
require "switest/esl/client"
require "switest/esl/call"

# High-level abstractions
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

  # Configuration holder.
  #
  # @example
  #   Switest.configure do |config|
  #     config.host = "192.168.1.100"
  #     config.log_level = Logger::INFO
  #   end
  #
  class Configuration
    attr_accessor :host, :port, :password, :log_level

    def initialize
      @host = Constants::Defaults::HOST
      @port = Constants::Defaults::PORT
      @password = Constants::Defaults::PASSWORD
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
