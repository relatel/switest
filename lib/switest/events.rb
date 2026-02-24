# frozen_string_literal: true

module Switest
  # Custom EventEmitter with guard support for conditional event handling.
  # Supports hash equality, regex, array membership, and proc guards.
  class Events
    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
      @handler_id = 0
    end

    # Register a permanent event handler with optional guards
    def on(event, guards = {}, &block)
      @handler_id += 1
      @handlers[event] << {
        id: @handler_id,
        guards: guards,
        callback: block,
        once: false
      }
      @handler_id
    end

    # Register a one-time event handler with optional guards
    def once(event, guards = {}, &block)
      @handler_id += 1
      @handlers[event] << {
        id: @handler_id,
        guards: guards,
        callback: block,
        once: true
      }
      @handler_id
    end

    # Emit an event, triggering all matching handlers
    def emit(event, data = {})
      handlers_to_call = []
      handlers_to_remove = []

      @handlers[event].each do |handler|
        if guards_match?(handler[:guards], data)
          handlers_to_call << handler
          handlers_to_remove << handler[:id] if handler[:once]
        end
      end

      handlers_to_call.each { |handler| handler[:callback].call(data) }

      handlers_to_remove.each do |id|
        @handlers[event].reject! { |h| h[:id] == id }
      end
    end

    # Remove handler(s) for an event
    def off(event, handler_id = nil)
      if handler_id
        @handlers[event].reject! { |h| h[:id] == handler_id }
      else
        @handlers.delete(event)
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
