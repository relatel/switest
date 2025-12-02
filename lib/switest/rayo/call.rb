# frozen_string_literal: true

require "concurrent"

module Switest
  module Rayo
    # Represents a call (inbound or outbound) and provides methods for control.
    # Tracks call state and provides event callbacks.
    class Call
      attr_reader :id, :jid, :to, :from, :headers
      attr_reader :start_time, :answer_time, :end_reason

      def initialize(client, jid:, to: nil, from: nil, headers: {})
        @client = client
        @jid = jid
        @id = jid.node
        @to = to
        @from = from
        @headers = headers
        @start_time = Time.now
        @answer_time = nil
        @end_reason = nil
        @state = :offered
        @answer_callbacks = Concurrent::Array.new
        @end_callbacks = Concurrent::Array.new
        @mutex = Mutex.new
      end

      # Create from an Offer stanza
      def self.from_offer(client, offer)
        new(
          client,
          jid: offer.call_jid,
          to: offer.to_uri,
          from: offer.from_uri,
          headers: offer.headers
        )
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

        @client.send_command(Answer.new(@jid))
      end

      def hangup(headers = {})
        return if ended?

        @client.send_command(Hangup.new(@jid, headers))
      end

      def reject(reason = :decline, headers = {})
        raise CallError, "Cannot reject a call that is not offered" unless offered?

        @client.send_command(Reject.new(@jid, reason, headers))
      end

      # Play audio (used for DTMF tones)
      # url can be like "tone_stream://d=200;1" for DTMF digits
      def play_audio(url)
        raise CallError, "Cannot play audio on a call that is not active" unless active?

        @client.send_command(Output.new(@jid, url))
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
    end

    class CallError < StandardError; end
  end
end
