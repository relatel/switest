# frozen_string_literal: true

module Switest2
  class Configuration
    attr_accessor :host, :port, :password, :default_timeout

    def initialize
      @host = "127.0.0.1"
      @port = 8021
      @password = "ClueCon"
      @default_timeout = 5
    end

    def to_h
      {
        host: @host,
        port: @port,
        password: @password,
        default_timeout: @default_timeout
      }
    end
  end
end
