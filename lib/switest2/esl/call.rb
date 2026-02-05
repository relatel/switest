# frozen_string_literal: true

require "concurrent"

module Switest2
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
        @headers = Switest2::CaseInsensitiveHash.from(headers)

        @state = :offered
        @start_time = Time.now
        @answer_time = nil
        @end_time = nil
        @end_reason = nil

        @dtmf_buffer = Queue.new
        @callbacks = { answer: [], end: [] }
        @mutex = Mutex.new

        @answered_latch = Concurrent::CountDownLatch.new(1)
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

      def inbound?
        @direction == :inbound
      end

      def outbound?
        @direction == :outbound
      end

      # Actions
      def answer(wait: false)
        return unless @state == :offered && inbound?
        sendmsg("execute", "answer")
        return unless wait
        timeout = wait == true ? 5 : wait
        wait_for_answer(timeout: timeout)
      end

      def hangup(cause = "NORMAL_CLEARING", wait: false)
        return if ended?
        msg = +"sendmsg #{@id}\n"
        msg << "call-command: hangup\n"
        msg << "hangup-cause: #{cause}"
        @connection.send_command(msg)
        return unless wait
        timeout = wait == true ? 5 : wait
        wait_for_end(timeout: timeout)
      end

      def reject(reason = :decline)
        return unless @state == :offered && inbound?
        cause = case reason
                when :busy then "USER_BUSY"
                when :decline then "CALL_REJECTED"
                else "CALL_REJECTED"
                end
        hangup(cause)
      end

      def play_audio(url, wait: true)
        sendmsg("execute", "playback", url, event_lock: wait)
      end

      def send_dtmf(digits, wait: true)
        # Play DTMF tones (inband)
        tones = digits.chars.map { |d| dtmf_tone(d) }.join(";")
        sendmsg("execute", "playback", "tone_stream://#{tones}", event_lock: wait)
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

      def on_end(&block)
        @mutex.synchronize { @callbacks[:end] << block }
      end

      # Blocking waits
      def wait_for_answer(timeout: 5)
        @answered_latch.wait(timeout)
        answered?
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

      def handle_hangup(cause, headers = {})
        @mutex.synchronize do
          return if @state == :ended
          @state = :ended
          @end_time = Time.now
          @end_reason = cause
          @headers.merge!(headers)
        end
        @answered_latch.count_down  # Release any waiting threads
        @ended_latch.count_down
        fire_callbacks(:end)
      end

      def handle_dtmf(digit)
        @dtmf_buffer.push(digit)
      end

      private

      def sendmsg(command, app = nil, arg = nil, event_lock: false)
        msg = +"sendmsg #{@id}\n"
        msg << "call-command: #{command}\n"
        msg << "execute-app-name: #{app}\n" if app
        msg << "execute-app-arg: #{arg}\n" if arg
        msg << "event-lock: true\n" if event_lock
        @connection.send_command(msg.chomp)
      end

      def dtmf_tone(digit)
        # DTMF tone frequencies
        freqs = {
          "1" => "697,1209", "2" => "697,1336", "3" => "697,1477",
          "4" => "770,1209", "5" => "770,1336", "6" => "770,1477",
          "7" => "852,1209", "8" => "852,1336", "9" => "852,1477",
          "0" => "941,1336", "*" => "941,1209", "#" => "941,1477"
        }
        freq = freqs[digit] || "697,1209"
        "%(100,100,#{freq})"
      end

      def fire_callbacks(type)
        callbacks = @mutex.synchronize { @callbacks[type].dup }
        callbacks.each { |cb| cb.call(self) }
      end
    end
  end
end
