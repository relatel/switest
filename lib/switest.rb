# frozen_string_literal: true

require_relative "switest/version"
require_relative "switest/configuration"
require_relative "switest/case_insensitive_hash"
require_relative "switest/events"
require_relative "switest/esl/escaper"
require_relative "switest/esl/event"
require_relative "switest/esl/connection"
require_relative "switest/esl/call"
require_relative "switest/esl/client"
require_relative "switest/agent"
require_relative "switest/scenario"

module Switest
  class Error < StandardError; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class TimeoutError < Error; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end
end
