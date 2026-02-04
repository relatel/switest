# frozen_string_literal: true

module Switest2
  class Configuration
    attr_accessor :host, :port, :password, :log_level, :default_timeout

    def initialize
      @host = "127.0.0.1"
      @port = 8021
      @password = "ClueCon"
      @log_level = :error
      @default_timeout = 5
    end

    def to_h
      {
        host: @host,
        port: @port,
        password: @password,
        log_level: @log_level,
        default_timeout: @default_timeout
      }
    end
  end
end
