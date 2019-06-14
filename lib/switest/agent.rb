# encoding: utf-8

module Switest
  class Agent
    include Celluloid
    include HasGuardedHandlers

    attr_accessor :call

    def self.dial(*args)
      agent = Agent.new
      agent.dial(*args)
      agent
    end

    def self.listen_for_call(*args)
      agent = Agent.new
      agent.listen_for_call(*args)
      agent
    end

    def call?
      !!@call
    end

    def dial(*args)
      @call = ::Adhearsion::OutboundCall.originate(*args)
    end

    def answer(*args)
      @call.answer(*args)
    end

    def hangup(*args)
      @call.hangup(*args)
    end

    def reject(*args)
      @call.reject(*args)
    end

    def send_dtmf(dtmf)
      controller = ::Adhearsion::CallController.new(@call) do
        play_audio("tone_stream://d=200;#{dtmf}")
      end
      controller.exec
    end

    def receive_dtmf(*args)
      input = nil
      controller = ::Adhearsion::CallController.new(@call) do
        input = ask(*args)
      end
      controller.exec
      input.utterance
    end

    def listen_for_call(conditions={})
      Switest.events.register_tmp_handler(:inbound_call, conditions) {|call|
        @call = call
        trigger_handler(:call, call)
      }
    end

    def wait_for_call(timeout: 5)
      return if @call
      wait(timeout) {|blocker|
        register_tmp_handler(:call) { blocker.signal }
      }
    end

    def wait_for_answer(timeout: 5)
      return if @call.start_time
      wait(timeout) {|blocker|
        @call.on_answer { blocker.signal }
      }
    end

    def wait_for_end(timeout: 5)
      return if @call.end_reason
      wait(timeout) {|blocker|
        @call.on_end { blocker.signal }
      }
    end

    private

    def wait(timeout)
      blocker = Celluloid::Condition.new
      timer = after(timeout) { blocker.signal }
      yield(blocker)
      blocker.wait
    end
  end
end
