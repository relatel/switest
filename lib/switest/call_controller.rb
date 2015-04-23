# encoding: utf-8

module Switest
  class CallController < ::Adhearsion::CallController
    def run
      call.auto_hangup = false
      case call
      when ::Adhearsion::OutboundCall
        nil
      else
        Switest.events.trigger_handler(:inbound_call, call)
      end
    end
  end
end
