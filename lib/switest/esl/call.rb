# frozen_string_literal: true

require "concurrent"
require "securerandom"

module Switest
  module ESL
    # Represents a call (inbound or outbound) and provides methods for control.
    class Call
      attr_reader :id, :to, :from, :headers
      attr_reader :start_time, :answer_time, :end_reason

      alias jid id

      def initialize(connection, uuid:, to: nil, from: nil, headers: {})
        @connection = connection
        @id = uuid
        @to = to
        @from = from
        @headers = headers
        @start_time = Time.now
        @answer_time = nil
        @end_reason = nil
        @state = :offered
        @answer_callbacks = Concurrent::Array.new
        @end_callbacks = Concurrent::Array.new
        @input_complete_callbacks = Concurrent::Array.new
        @mutex = Mutex.new
      end

      # Normalized headers with keys transformed: downcase and - to _
      def variables
        @variables ||= normalize_headers(@headers)
      end

      # Call state queries

      def alive?
        @state != :ended
      end

      def active?
        @state == :answered
      end

      def answered?
        @state == :answered
      end

      def offered?
        @state == :offered
      end

      def ended?
        @state == :ended
      end

      # Call control commands

      def answer
        raise CallError, "Cannot answer a call that is not offered" unless offered?

        @connection.sendmsg(@id, app: "answer")
      end

      def hangup(headers = {})
        return if ended?

        cause = headers[:cause] || headers["cause"] || "NORMAL_CLEARING"
        @connection.sendmsg(@id, app: "hangup", arg: cause)
      end

      def reject(reason = :decline, headers = {})
        raise CallError, "Cannot reject a call that is not offered" unless offered?

        # Map reasons to SIP response codes
        code = case reason
               when :busy then "486"
               when :decline then "603"
               when :error then "500"
               else "603"
               end

        @connection.sendmsg(@id, app: "respond", arg: code)
      end

      # Play audio (used for DTMF tones)
      # url can be like "tone_stream://d=200;1" for DTMF digits
      def play_audio(url)
        raise CallError, "Cannot play audio on a call that is not active" unless active?

        @connection.sendmsg(@id, app: "playback", arg: url, async: true)
      end

      # Receive DTMF digits from the caller
      # @param max_digits [Integer] Maximum number of digits to collect
      # @param timeout [Numeric] Timeout in seconds
      # @param terminator [String, nil] Digit that terminates input (e.g., "#")
      # @return [String, nil] The collected digits, or nil on timeout/nomatch
      def receive_dtmf(max_digits:, timeout: 5, terminator: "#")
        raise CallError, "Cannot receive DTMF on a call that is not active" unless active?

        result = nil
        complete_event = Concurrent::Event.new

        on_input_complete do |digits|
          result = digits
          complete_event.set
        end

        # Use read application: read <min> <max> <sound> <var> <timeout_ms> <terminators>
        timeout_ms = timeout * 1000
        @connection.sendmsg(@id,
          app: "read",
          arg: "1 #{max_digits} silence_stream://250 dtmf_result #{timeout_ms} #{terminator}"
        )

        complete_event.wait(timeout + 5)
        result
      end

      # Event callbacks

      def on_answer(&block)
        if answered?
          block.call
        else
          @answer_callbacks << block
        end
      end

      def on_end(&block)
        if ended?
          block.call
        else
          @end_callbacks << block
        end
      end

      def on_input_complete(&block)
        @input_complete_callbacks << block
      end

      # Called by Client when events are received

      def handle_answered
        callbacks_to_run = @mutex.synchronize do
          return if @state == :answered || @state == :ended

          @answer_time = Time.now
          @state = :answered
          callbacks = @answer_callbacks.dup
          @answer_callbacks.clear
          callbacks
        end
        callbacks_to_run&.each(&:call)
      end

      def handle_end(reason)
        callbacks_to_run = @mutex.synchronize do
          return if @state == :ended

          @end_reason = reason
          @state = :ended
          callbacks = @end_callbacks.dup
          @end_callbacks.clear
          callbacks
        end
        callbacks_to_run&.each(&:call)
      end

      def handle_input_complete(digits)
        callbacks_to_run = @mutex.synchronize do
          callbacks = @input_complete_callbacks.dup
          @input_complete_callbacks.clear
          callbacks
        end
        callbacks_to_run&.each { |cb| cb.call(digits) }
      end

      # Handle ESL events for this call
      def handle_event(event)
        case event.name
        when "CHANNEL_ANSWER"
          handle_answered
        when "CHANNEL_HANGUP", "CHANNEL_HANGUP_COMPLETE"
          handle_end(event.hangup_cause&.downcase&.to_sym || :hangup)
        when "CHANNEL_EXECUTE_COMPLETE"
          if event.application == "read"
            digits = event.variable("dtmf_result") || event.variable("read_result")
            handle_input_complete(digits)
          end
        end
      end

      # Wait for answer with timeout
      def wait_for_answer(timeout: 5)
        return true if answered?
        return false if ended?

        event = Concurrent::Event.new
        on_answer { event.set }
        on_end { event.set }

        event.wait(timeout)
        answered?
      end

      # Wait for end with timeout
      def wait_for_end(timeout: 5)
        return true if ended?

        event = Concurrent::Event.new
        on_end { event.set }

        event.wait(timeout)
        ended?
      end

      private

      def normalize_headers(headers)
        headers.transform_keys { |k| k.to_s.downcase.tr("-", "_") }
      end
    end
  end
end
