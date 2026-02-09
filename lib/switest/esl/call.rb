# frozen_string_literal: true

require "concurrent"

module Switest
  module ESL
    class Call
      attr_reader :id, :to, :from, :headers, :direction
      attr_reader :start_time, :answer_time, :end_time, :end_reason
      attr_reader :state

      def initialize(id:, connection:, direction:, to: nil, from: nil, headers: {})
        @id = id
        @connection = connection
        @direction = direction  # :inbound or :outbound
        @to = to
        @from = from
        @headers = Switest::CaseInsensitiveHash.from(headers)

        @state = :offered
        @start_time = Time.now
        @answer_time = nil
        @end_time = nil
        @end_reason = nil

        @bridged = false
        @dtmf_buffer = Queue.new
        @execute_complete = Queue.new
        @callbacks = { answer: [], bridge: [], end: [] }
        @mutex = Mutex.new

        @answered_latch = Concurrent::CountDownLatch.new(1)
        @bridged_latch = Concurrent::CountDownLatch.new(1)
        @ended_latch = Concurrent::CountDownLatch.new(1)
      end

      # State queries
      def alive?
        @state != :ended
      end

      def active?
        @state == :answered
      end

      def answered?
        @state == :answered || (@state == :ended && @answer_time)
      end

      def ended?
        @state == :ended
      end

      def bridged?
        @bridged
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
        msg = +"sendmsg #{@id}\n"
        msg << "call-command: hangup\n"
        msg << "hangup-cause: #{cause}"
        @connection.send_command(msg)
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
        sendmsg("execute", "playback", url, wait: wait)
      end

      def send_dtmf(digits, wait: true)
        play_audio("tone_stream://d=200;w=250;#{digits}", wait: wait)
      end

      def flush_dtmf
        @dtmf_buffer.clear
      end

      def receive_dtmf(count: 1, timeout: 5)
        digits = String.new
        deadline = Time.now + timeout

        count.times do
          remaining = deadline - Time.now
          break if remaining <= 0

          begin
            digit = @dtmf_buffer.pop(timeout: remaining)
            digits << digit if digit
          rescue ThreadError
            break # Timeout
          end
        end

        digits
      end

      # Callbacks
      def on_answer(&block)
        @mutex.synchronize { @callbacks[:answer] << block }
      end

      def on_bridge(&block)
        @mutex.synchronize { @callbacks[:bridge] << block }
      end

      def on_end(&block)
        @mutex.synchronize { @callbacks[:end] << block }
      end

      # Blocking waits
      def wait_for_answer(timeout: 5)
        @answered_latch.wait(timeout)
        answered?
      end

      def wait_for_bridge(timeout: 5)
        @bridged_latch.wait(timeout)
        bridged?
      end

      def wait_for_end(timeout: 5)
        @ended_latch.wait(timeout)
        ended?
      end

      # Internal state updates (called by Client)
      def handle_answer
        @mutex.synchronize do
          return if @state == :ended
          @state = :answered
          @answer_time = Time.now
        end
        @answered_latch.count_down
        fire_callbacks(:answer)
      end

      def handle_bridge
        @mutex.synchronize do
          return if @state == :ended
          @bridged = true
        end
        @bridged_latch.count_down
        fire_callbacks(:bridge)
      end

      def handle_hangup(cause, headers = {})
        @mutex.synchronize do
          return if @state == :ended
          @state = :ended
          @end_time = Time.now
          @end_reason = cause
          @headers.merge!(headers)
        end
        @answered_latch.count_down  # Release any waiting threads
        @bridged_latch.count_down
        @ended_latch.count_down
        fire_callbacks(:end)
      end

      def handle_execute_complete(application)
        @execute_complete.push(application)
      end

      def handle_dtmf(digit)
        @dtmf_buffer.push(digit)
      end

      private

      def sendmsg(command, app = nil, arg = nil, wait: false)
        msg = +"sendmsg #{@id}\n"
        msg << "call-command: #{command}\n"
        msg << "execute-app-name: #{app}\n" if app
        msg << "execute-app-arg: #{arg}\n" if arg
        msg << "event-lock: true\n" if wait
        @connection.send_command(msg.chomp)

        if wait
          timeout = wait.is_a?(Numeric) ? wait : 30
          @execute_complete.pop(timeout: timeout) rescue nil
        end
      end


      def fire_callbacks(type)
        callbacks = @mutex.synchronize { @callbacks[type].dup }
        callbacks.each { |cb| cb.call(self) }
      end
    end
  end
end
