# encoding: utf-8

require "adhearsion"

module Switest
  class Adhearsion
    def start
      start! unless @started
    end

    def start!
      ::Adhearsion::Plugin.configure_plugins
      ::Adhearsion.config do |config|
        config.core.logging.level = :error
        config.core.after_hangup_lifetime = 3600
        config.core.host = "127.0.0.1"
        config.core.port = 5222
        config.core.username = "switest@localhost"
        config.core.password = "1"
      end
      ::Adhearsion.router do
        route "Default", Switest::CallController
      end
      ::Adhearsion::Logging.start(
        ::Adhearsion.config.core.logging.level,
        ::Adhearsion.config.core.logging.formatter
      )
      ::Adhearsion::Events.register_handler :exception do |e, l|
        (l || ::Adhearsion.logger).error e
      end 
      ::Adhearsion::Rayo::Initializer.init
      ::Adhearsion::Plugin.init_plugins
      ::Adhearsion::Plugin.run_plugins
      ::Adhearsion::Rayo::Initializer.run
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

    def stop
      ::Adhearsion::Rayo::Initializer.client.stop
    end
  end
end
