# frozen_string_literal: true

module Switest2
  # Custom EventEmitter with guard support for conditional event handling.
  # Supports hash equality, regex, array membership, and proc guards.
  class Events
    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
      @handler_id = 0
      @mutex = Mutex.new
    end

    # Register a permanent event handler with optional guards
    # @param event [Symbol] Event name
    # @param guards [Hash] Guard conditions (hash equality, regex, array, or proc)
    # @return [Integer] Handler ID for later removal
    def on(event, guards = {}, &block)
      @mutex.synchronize do
        @handler_id += 1
        @handlers[event] << {
          id: @handler_id,
          guards: guards,
          callback: block,
          once: false
        }
        @handler_id
      end
    end

    # Register a one-time event handler with optional guards
    # @param event [Symbol] Event name
    # @param guards [Hash] Guard conditions
    # @return [Integer] Handler ID
    def once(event, guards = {}, &block)
      @mutex.synchronize do
        @handler_id += 1
        @handlers[event] << {
          id: @handler_id,
          guards: guards,
          callback: block,
          once: true
        }
        @handler_id
      end
    end

    # Emit an event, triggering all matching handlers
    # @param event [Symbol] Event name
    # @param data [Hash] Event data to pass to handlers
    def emit(event, data = {})
      handlers_to_call = []
      handlers_to_remove = []

      @mutex.synchronize do
        @handlers[event].each do |handler|
          if guards_match?(handler[:guards], data)
            handlers_to_call << handler
            handlers_to_remove << handler[:id] if handler[:once]
          end
        end
      end

      handlers_to_call.each { |handler| handler[:callback].call(data) }

      @mutex.synchronize do
        handlers_to_remove.each do |id|
          @handlers[event].reject! { |h| h[:id] == id }
        end
      end
    end

    # Remove handler(s) for an event
    # @param event [Symbol] Event name
    # @param handler_id [Integer, nil] Specific handler ID, or nil to remove all
    def off(event, handler_id = nil)
      @mutex.synchronize do
        if handler_id
          @handlers[event].reject! { |h| h[:id] == handler_id }
        else
          @handlers.delete(event)
        end
      end
    end

    private

    # Check if all guards match the provided data (AND logic)
    def guards_match?(guards, data)
      guards.all? do |key, guard|
        value = data[key]
        case guard
        when Hash
          value == guard
        when Regexp
          guard.match?(value.to_s)
        when Array
          guard.include?(value)
        when Proc
          guard.call(value)
        else
          value == guard
        end
      end
    end
  end
end
