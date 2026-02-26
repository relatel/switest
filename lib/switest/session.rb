# frozen_string_literal: true

require "librevox"
require "async/promise"

module Switest
  # Inbound ESL session built on librevox.
  #
  # A single connection to FreeSWITCH that handles both commands and events
  # (filtered by UUID). Events are dispatched to Call objects via the
  # call_registry. Unknown CHANNEL_PARK events trigger the offer_handler for
  # inbound call detection.
  class Session < Librevox::Listener::Inbound
      class << self
        attr_accessor :call_registry      # { uuid => Call }
        attr_accessor :offer_handler      # Proc for inbound call offers
        attr_accessor :connection_promise  # Async::Promise resolved when connected
      end

      def connection_completed
        self.class.connection_promise&.resolve(self)
      end

      def on_event(event)
        uuid = event.content[:unique_id]
        call = self.class.call_registry&.[](uuid)

        case event.event
        when "CHANNEL_ANSWER", "CHANNEL_BRIDGE", "CHANNEL_HANGUP",
             "CHANNEL_HANGUP_COMPLETE", "DTMF"
          call&.handle_event(event)
        when "CHANNEL_PARK"
          if call
            call.handle_event(event)
          else
            self.class.offer_handler&.call(event)
          end
        end
      end

      def bgapi(cmd)
        command("bgapi #{cmd}")
      end
  end
end
