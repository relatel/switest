# frozen_string_literal: true

require "concurrent"

module Switest
  # Simple event pub/sub system.
  #
  # Provides a lightweight publish/subscribe mechanism for event handling.
  # Supports both permanent and one-time handlers with condition matching.
  #
  # @example
  #   events = Events.new
  #   events.register_handler(:call, to: /^1234/) { |call| puts "Got call!" }
  #   events.trigger(:call, call_object)
  #
  class Events
    def initialize
      @handlers = Concurrent::Map.new { |h, k| h[k] = Concurrent::Array.new }
    end

    # Register a permanent handler for an event type.
    #
    # @param event_type [Symbol] Event type to handle
    # @param conditions [Hash] Conditions to match
    # @yield Called when event matches conditions
    # @return [Handler] The registered handler
    def register_handler(event_type, conditions = {}, &block)
      handler = Handler.new(block, conditions, permanent: true)
      @handlers[event_type] << handler
      handler
    end

    # Register a one-time handler that is removed after first match.
    #
    # @param event_type [Symbol] Event type to handle
    # @param conditions [Hash] Conditions to match
    # @yield Called when event matches conditions (once)
    # @return [Handler] The registered handler
    def register_tmp_handler(event_type, conditions = {}, &block)
      handler = Handler.new(block, conditions, permanent: false)
      @handlers[event_type] << handler
      handler
    end

    # Trigger an event, calling all matching handlers.
    #
    # @param event_type [Symbol] Event type to trigger
    # @param args [Array] Arguments to pass to handlers
    def trigger(event_type, *args)
      return unless @handlers.key?(event_type)

      handlers_to_remove = []

      @handlers[event_type].each do |handler|
        next unless handler.matches?(*args)

        begin
          handler.call(*args)
        rescue StandardError => e
          Switest.logger&.error("Error in event handler: #{e.message}")
        end

        handlers_to_remove << handler unless handler.permanent?
      end

      handlers_to_remove.each { |h| @handlers[event_type].delete(h) }
    end

    alias trigger_handler trigger

    # Remove a specific handler.
    #
    # @param event_type [Symbol] Event type
    # @param handler [Handler] Handler to remove
    def unregister_handler(event_type, handler)
      @handlers[event_type]&.delete(handler)
    end

    # Clear all handlers for an event type.
    #
    # @param event_type [Symbol, nil] Event type to clear, or nil to clear all
    def clear_handlers(event_type = nil)
      if event_type
        @handlers.delete(event_type)
      else
        @handlers.clear
      end
    end

    # Handler wrapper with condition matching.
    #
    # Delegates condition matching to ConditionMatcher for consistent
    # matching behavior across the library.
    class Handler
      attr_reader :conditions

      # @param block [Proc] Block to call when triggered
      # @param conditions [Hash] Conditions to match
      # @param permanent [Boolean] Whether handler persists after triggering
      def initialize(block, conditions, permanent:)
        @block = block
        @conditions = conditions
        @matcher = ConditionMatcher.new(conditions)
        @permanent = permanent
      end

      # @return [Boolean] true if handler persists after triggering
      def permanent?
        @permanent
      end

      # Check if arguments match the handler's conditions.
      #
      # @param args [Array] Arguments to match against
      # @return [Boolean] true if conditions match
      def matches?(*args)
        @matcher.match?(args.first)
      end

      # Call the handler block.
      #
      # @param args [Array] Arguments to pass to the block
      def call(*args)
        @block.call(*args)
      end
    end
  end
end
