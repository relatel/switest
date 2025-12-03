# frozen_string_literal: true

module Switest
  # Matches objects against a set of conditions.
  #
  # Supports multiple condition types:
  #   - Regexp: Match against string representation
  #   - Proc: Call with actual value
  #   - Array [:[], key]: Access object's variables/hash
  #   - Other: Equality comparison
  #
  # @example
  #   matcher = ConditionMatcher.new(to: /^1234/, sofia_profile: "switest_tdc")
  #   matcher.match?(call) # => true/false
  #
  class ConditionMatcher
    # @param conditions [Hash] Conditions to match against
    def initialize(conditions = {})
      @conditions = conditions
    end

    # Check if an object matches all conditions.
    #
    # @param obj [Object] Object to match against
    # @return [Boolean] true if all conditions match
    def match?(obj)
      return true if @conditions.empty?
      return true unless matchable?(obj)

      @conditions.all? do |key, expected|
        actual = extract_value(obj, key)
        compare(actual, expected)
      end
    end

    # @return [Boolean] true if no conditions are set
    def empty?
      @conditions.empty?
    end

    private

    # Check if object is matchable (has to/from methods).
    #
    # @param obj [Object] Object to check
    # @return [Boolean]
    def matchable?(obj)
      obj.respond_to?(:to) || obj.respond_to?(:from)
    end

    # Extract a value from an object based on the key type.
    #
    # @param obj [Object] Source object
    # @param key [Symbol, Array] Key or accessor specification
    # @return [Object, nil] Extracted value
    def extract_value(obj, key)
      case key
      when Array
        extract_array_accessor(obj, key)
      else
        extract_method_value(obj, key)
      end
    end

    # Handle array-style accessor [:[], :key].
    #
    # @param obj [Object] Source object
    # @param key [Array] Accessor specification [method, arg]
    # @return [Object, nil] Extracted value
    def extract_array_accessor(obj, key)
      return nil unless key.first == :[]

      header_key = key[1].to_s
      return nil unless obj.respond_to?(:variables)

      obj.variables[header_key]
    end

    # Extract value using method call.
    #
    # @param obj [Object] Source object
    # @param key [Symbol] Method name
    # @return [Object, nil] Extracted value
    def extract_method_value(obj, key)
      return nil unless obj.respond_to?(key)

      obj.send(key)
    end

    # Compare actual value against expected condition.
    #
    # @param actual [Object] Actual value
    # @param expected [Object] Expected value or matcher
    # @return [Boolean] true if values match
    def compare(actual, expected)
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
end
