# frozen_string_literal: true

require "async"
require "async/promise"

module Switest
  class Agent
    class << self
      # Shared client for all agents in a test
      attr_accessor :client, :events

      def setup(client, events)
        @client = client
        @events = events
      end

      def teardown
        @client = nil
        @events = nil
      end

      def dial(destination, from: nil, timeout: nil, headers: {})
        raise "Agent.setup not called" unless @client

        call = @client.dial(to: destination, from: from, timeout: timeout, headers: headers)
        new(call)
      end

      def listen_for_call(guards = {})
        raise "Agent.setup not called" unless @client

        agent = new(nil)

        # Register a one-time handler for matching inbound calls
        @events.once(:offer, guards) do |data|
          agent.receive_call(data[:call])
        end

        agent
      end
    end

    attr_reader :call

    def initialize(call)
      @call = call
      @call_promise = Async::Promise.new
    end

    def call?
      !@call.nil?
    end

    def answer(wait: 5)
      raise "No call to answer" unless @call
      @call.answer(wait: wait)
    end

    def hangup(wait: 5)
      raise "No call to hangup" unless @call
      @call.hangup(wait: wait)
    end

    def reject(reason = :decline)
      raise "No call to reject" unless @call
      @call.reject(reason)
    end

    def send_dtmf(digits)
      raise "No call for DTMF" unless @call
      @call.send_dtmf(digits)
    end

    def receive_dtmf(count: 1, timeout: 5)
      raise "No call for DTMF" unless @call
      @call.receive_dtmf(count: count, timeout: timeout)
    end

    def flush_dtmf
      raise "No call for DTMF" unless @call
      @call.flush_dtmf
    end

    def wait_for_call(timeout: 5)
      return true if @call
      Async::Task.current.with_timeout(timeout) { @call_promise.wait }
      !@call.nil?
    rescue Async::TimeoutError
      !@call.nil?
    end

    def wait_for_answer(timeout: 5)
      raise "No call to wait for" unless @call
      @call.wait_for_answer(timeout: timeout)
    end

    def wait_for_bridge(timeout: 5)
      raise "No call to wait for" unless @call
      @call.wait_for_bridge(timeout: timeout)
    end

    def wait_for_end(timeout: 5)
      raise "No call to wait for" unless @call
      @call.wait_for_end(timeout: timeout)
    end

    # Delegate state queries to call
    def alive?
      @call&.alive? || false
    end

    def active?
      @call&.active? || false
    end

    def answered?
      @call&.answered? || false
    end

    def ended?
      @call&.ended? || false
    end

    def bridged?
      @call&.bridged? || false
    end

    def outbound?
      @call&.outbound? || false
    end

    def inbound?
      @call&.inbound? || false
    end

    def id
      @call&.id
    end

    def start_time
      @call&.start_time
    end

    def answer_time
      @call&.answer_time
    end

    def end_time
      @call&.end_time
    end

    def end_reason
      @call&.end_reason
    end

    def headers
      @call&.headers
    end

    # @api private — called by listen_for_call handler
    def receive_call(call)
      @call = call
      @call_promise.resolve(true)
    end
  end
end
