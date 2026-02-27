# frozen_string_literal: true

module Switest
  # Lightweight one-shot event emitter with guard support for conditional
  # event handling. Supports hash equality, regex, array membership, and
  # proc guards.
  #
  # Used for routing inbound call offers from Client to Agent.listen_for_call.
  class Events
    def initialize
      @handlers = Hash.new { |h, k| h[k] = [] }
    end

    # Register a one-time event handler with optional guards
    def once(event, guards = {}, &block)
      @handlers[event] << { guards: guards, callback: block }
    end

    # Emit an event, triggering and removing all matching handlers
    def emit(event, data = {})
      matched = []
      remaining = []

      @handlers[event].each do |handler|
        if guards_match?(handler[:guards], data)
          matched << handler
        else
          remaining << handler
        end
      end

      @handlers[event] = remaining
      matched.each { |handler| handler[:callback].call(data) }
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
