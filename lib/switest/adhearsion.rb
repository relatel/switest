# encoding: utf-8

require "adhearsion"
require "adhearsion-asr"

module Switest
  class Adhearsion
    def start
      start! unless @started
    end

    def start!
      ::Adhearsion::Plugin.configure_plugins
      ::Adhearsion.config do |config|
        config.development do |dev|
          dev.platform.logging.level = :error
        end
        config.platform.after_hangup_lifetime = 3600
        config.punchblock.username = "switest@localhost"
        config.punchblock.password = "1"
      end
      ::Adhearsion.router do
        route "Default", Switest::CallController
      end
      ::Adhearsion::Logging.start(
        nil,
        ::Adhearsion.config.platform.logging.level,
        ::Adhearsion.config.platform.logging.formatter
      )
      ::Adhearsion::Events.register_handler :exception do |e, l|
        (l || ::Adhearsion.logger).error e
      end 
      ::Adhearsion::Plugin.init_plugins
      ::Adhearsion::Plugin.run_plugins
      @started = true
      true
    end

    def cleanup
      ::Adhearsion.active_calls.values.each {|call|
        if call.alive? && call.active?
          begin
            call.hangup
            call.wait_for_end
          rescue ::Adhearsion::Call::Hangup
            Switest.logger.debug("Call was already hungup")
          end
        end
      }
    end
  end
end
