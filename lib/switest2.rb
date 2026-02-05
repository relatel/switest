# frozen_string_literal: true

require_relative "switest2/version"
require_relative "switest2/configuration"
require_relative "switest2/case_insensitive_hash"
require_relative "switest2/events"
require_relative "switest2/esl/escaper"
require_relative "switest2/esl/event"
require_relative "switest2/esl/connection"
require_relative "switest2/esl/call"
require_relative "switest2/esl/client"
require_relative "switest2/agent"
require_relative "switest2/scenario"

module Switest2
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

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
