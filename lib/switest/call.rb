# frozen_string_literal: true

require "async"
require "async/promise"
require "async/queue"

module Switest
  class Call
    attr_reader :id, :to, :from, :headers, :direction
    attr_reader :start_time, :answer_time, :end_time, :end_reason
    attr_reader :state

    def initialize(id:, direction:, to: nil, from: nil, headers: {}, session: nil)
      @id = id
      @session = session
      @direction = direction  # :inbound or :outbound
      @to = to
      @from = from
      @headers = headers.is_a?(Hash) ? headers.dup : {}

      @state = :offered
      @start_time = Time.now
      @answer_time = nil
      @end_time = nil
      @end_reason = nil

      @dtmf_queue = Async::Queue.new

      @answered_promise = Async::Promise.new
      @ended_promise = Async::Promise.new
    end

    # State queries
    def alive?
      @state != :ended
    end

    def active?
      @state == :answered
    end

    def answered?
      @state == :answered
    end

    def ended?
      @state == :ended
    end

    def inbound?
      @direction == :inbound
    end

    def outbound?
      @direction == :outbound
    end

    # Actions
    def answer(wait: 5)
      return unless @state == :offered && inbound?
      sendmsg("execute", "answer")
      return unless wait
      wait_for_answer(timeout: wait)
    end

    def hangup(cause = "NORMAL_CLEARING", wait: 5)
      return if ended?
      sendmsg("hangup", hangup_cause: cause)
      return unless wait
      wait_for_end(timeout: wait)
    end

    def reject(reason = :decline, wait: 5)
      return unless @state == :offered && inbound?
      cause = case reason
              when :busy then "USER_BUSY"
              when :decline then "CALL_REJECTED"
              else "CALL_REJECTED"
              end
      hangup(cause, wait: wait)
    end

    def play_audio(url, wait: true)
      sendmsg("execute", "playback", url, event_lock: wait)
    end

    def send_dtmf(digits, wait: true)
      play_audio("tone_stream://d=200;w=250;#{digits}", wait: wait)
    end

    def flush_dtmf
      @dtmf_queue.dequeue until @dtmf_queue.empty?
    end

    def receive_dtmf(count: 1, timeout: 5)
      digits = String.new
      deadline = Time.now + timeout

      count.times do
        remaining = deadline - Time.now
        break if remaining <= 0

        Async::Task.current.with_timeout(remaining) do
          digits << @dtmf_queue.dequeue
        end
      rescue Async::TimeoutError
        break
      end

      digits
    end

    # Blocking waits
    def wait_for_answer(timeout: 5)
      return true if answered?
      Async::Task.current.with_timeout(timeout) { @answered_promise.wait }
      answered?
    rescue Async::TimeoutError
      answered?
    end

    def wait_for_end(timeout: 5)
      return true if ended?
      Async::Task.current.with_timeout(timeout) { @ended_promise.wait }
      ended?
    rescue Async::TimeoutError
      ended?
    end

    # Internal: dispatch a librevox Response event to the appropriate handler.
    def handle_event(response)
      return unless response.event?

      case response.event
      when "CHANNEL_ANSWER"
        handle_answer
      when "CHANNEL_CALLSTATE"
        handle_callstate(response.content[:channel_call_state])
      when "CHANNEL_HANGUP_COMPLETE"
        cause = response.content[:hangup_cause]
        handle_hangup(cause, response.content)
      when "DTMF"
        digit = response.content[:dtmf_digit]
        handle_dtmf(digit) if digit
      end
    end

    # Internal state updates
    def handle_answer
      return if @state == :ended
      @state = :ringing
      @answer_time = Time.now
    end

    def handle_callstate(call_state)
      return if @state == :ended
      return unless call_state == "ACTIVE"

      @state = :answered
      @answered_promise.resolve(true)
    end

    def handle_hangup(cause, event_content = {})
      return if @state == :ended
      @state = :ended
      @end_time = Time.now
      @end_reason = cause

      # Merge event data into headers
      if event_content.is_a?(Hash)
        event_content.each do |k, v|
          next if k == :body
          @headers[k] = v.to_s
        end
      end

      @answered_promise.resolve(true)
      @ended_promise.resolve(true)
    end

    def handle_dtmf(digit)
      @dtmf_queue.enqueue(digit)
    end

    private

    def sendmsg(command, app = nil, arg = nil, event_lock: false, hangup_cause: nil)
      msg = +"sendmsg #{@id}\n"
      msg << "call-command: #{command}\n"
      msg << "execute-app-name: #{app}\n" if app
      msg << "execute-app-arg: #{arg}\n" if arg
      msg << "event-lock: true\n" if event_lock
      msg << "hangup-cause: #{hangup_cause}" if hangup_cause
      @session.command(msg.chomp)
    end

  end
end
