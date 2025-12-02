# frozen_string_literal: true

require "concurrent"

module Switest
  # Agent represents a call participant in a test scenario.
  # Can dial outbound calls or listen for inbound calls.
  class Agent
    attr_accessor :call

    def self.dial(*args, **kwargs)
      agent = Agent.new
      agent.dial(*args, **kwargs)
      agent
    end

    def self.listen_for_call(conditions = {})
      agent = Agent.new
      agent.listen_for_call(conditions)
      agent
    end

    def initialize
      @call = nil
      @call_event = Concurrent::Event.new
      @local_handlers = Events.new
    end

    def call?
      !@call.nil?
    end

    # Dial an outbound call
    # @param to [String] The destination URI (e.g., "sip:user@domain" or "tel:+1234567890")
    # @param from [String, nil] The caller ID URI
    # @param headers [Hash] Optional SIP headers
    def dial(to, from: nil, headers: {})
      @call = Switest.connection.client.dial(to: to, from: from, headers: headers)
    end

    def answer
      @call.answer
    end

    def hangup
      @call.hangup
    end

    def reject(reason = :decline)
      @call.reject(reason)
    end

    # Send DTMF digits
    # @param dtmf [String] The DTMF digits to send (e.g., "123#")
    def send_dtmf(dtmf)
      # Convert DTMF digits to tone_stream format for FreeSWITCH
      @call.play_audio("tone_stream://d=200;#{dtmf}")
    end

    # Listen for an inbound call matching the given conditions
    # @param conditions [Hash] Conditions to match (e.g., { to: /pattern/ })
    def listen_for_call(conditions = {})
      Switest.events.register_tmp_handler(:inbound_call, conditions) do |call|
        @call = call
        @call_event.set
        @local_handlers.trigger(:call, call)
      end
    end

    # Wait for an inbound call to arrive
    # @param timeout [Numeric] Maximum time to wait in seconds
    # @return [Boolean] true if call arrived, false if timeout
    def wait_for_call(timeout: 5)
      return true if @call

      @call_event.wait(timeout)
      !@call.nil?
    end

    # Wait for the call to be answered
    # @param timeout [Numeric] Maximum time to wait in seconds
    # @return [Boolean] true if answered, false if timeout
    def wait_for_answer(timeout: 5)
      return true if @call&.answer_time

      @call&.wait_for_answer(timeout: timeout) || false
    end

    # Wait for the call to end
    # @param timeout [Numeric] Maximum time to wait in seconds
    # @return [Boolean] true if ended, false if timeout
    def wait_for_end(timeout: 5)
      return true if @call&.end_reason

      @call&.wait_for_end(timeout: timeout) || false
    end

    # Register a handler for local agent events
    def on(event_type, &block)
      @local_handlers.register_handler(event_type, &block)
    end

    # Register a one-time handler for local agent events
    def once(event_type, &block)
      @local_handlers.register_tmp_handler(event_type, &block)
    end
  end
end
