# frozen_string_literal: true

require "concurrent"

module Switest
  # Simple event pub/sub system.
  # Replaces HasGuardedHandlers with a lightweight implementation.
  class Events
    def initialize
      @handlers = Concurrent::Map.new { |h, k| h[k] = Concurrent::Array.new }
    end

    # Register a permanent handler for an event type
    def register_handler(event_type, conditions = {}, &block)
      handler = Handler.new(block, conditions, permanent: true)
      @handlers[event_type] << handler
      handler
    end

    # Register a one-time handler that is removed after first match
    def register_tmp_handler(event_type, conditions = {}, &block)
      handler = Handler.new(block, conditions, permanent: false)
      @handlers[event_type] << handler
      handler
    end

    # Trigger an event, calling all matching handlers
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

    # Alias for compatibility
    alias trigger_handler trigger

    # Remove a specific handler
    def unregister_handler(event_type, handler)
      @handlers[event_type]&.delete(handler)
    end

    # Clear all handlers for an event type
    def clear_handlers(event_type = nil)
      if event_type
        @handlers.delete(event_type)
      else
        @handlers.clear
      end
    end

    # Handler wrapper with condition matching
    class Handler
      attr_reader :conditions

      def initialize(block, conditions, permanent:)
        @block = block
        @conditions = conditions
        @permanent = permanent
      end

      def permanent?
        @permanent
      end

      def matches?(*args)
        return true if @conditions.empty?

        # For call objects, match against call properties
        obj = args.first
        return true unless obj.respond_to?(:to) || obj.respond_to?(:from)

        @conditions.all? do |key, expected|
          actual = obj.respond_to?(key) ? obj.send(key) : nil
          case expected
          when Regexp
            expected.match?(actual.to_s)
          when Proc
            expected.call(actual)
          else
            actual == expected || actual.to_s == expected.to_s
          end
        end
      end

      def call(*args)
        @block.call(*args)
      end
    end
  end
end
