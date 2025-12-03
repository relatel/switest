# frozen_string_literal: true

module Switest
  module Concerns
    # Provides consistent logging interface for classes.
    #
    # @example
    #   class MyClass
    #     include Switest::Concerns::Loggable
    #
    #     def initialize(logger: nil)
    #       @logger = logger
    #     end
    #
    #     def do_something
    #       log(:info, "Doing something")
    #     end
    #   end
    #
    module Loggable
      # Log a message with the specified level.
      #
      # @param level [Symbol] Log level (:debug, :info, :warn, :error)
      # @param message [String] Message to log
      # @param context [Hash] Additional context (optional)
      def log(level, message, context = {})
        return unless logger

        formatted = format_log_message(message, context)
        logger.send(level, formatted)
      end

      private

      # Get the logger instance.
      # Subclasses should define @logger or override this method.
      #
      # @return [Logger, nil]
      def logger
        @logger
      end

      # Format log message with class context.
      #
      # @param message [String] Base message
      # @param context [Hash] Additional context
      # @return [String] Formatted message
      def format_log_message(message, context)
        prefix = log_prefix
        base = prefix ? "[#{prefix}] #{message}" : message

        return base if context.empty?

        context_str = context.map { |k, v| "#{k}=#{v}" }.join(" ")
        "#{base} #{context_str}"
      end

      # Get the log prefix for this class.
      # Override in subclasses for custom prefixes.
      #
      # @return [String, nil]
      def log_prefix
        self.class.name&.split("::")&.last
      end
    end
  end
end
