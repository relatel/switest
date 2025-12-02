# frozen_string_literal: true

require "concurrent"

module Switest
  # Timer provides scheduled callback functionality using concurrent-ruby.
  # Allows scheduling one-shot or repeating callbacks.
  #
  # Usage:
  #   timer = Switest::Timer.new
  #   timer.after(0.5) { puts "delayed" }
  #   timer.every(1.0) { puts "repeating" }
  #
  # Or use class methods:
  #   Switest::Timer.after(0.5) { puts "delayed" }
  #
  class Timer
    def initialize
      @tasks = Concurrent::Array.new
    end

    # Schedule a one-shot callback after a delay
    # @param delay [Numeric] Delay in seconds
    # @param block [Proc] The callback to execute
    # @return [Concurrent::ScheduledTask]
    def after(delay, &block)
      task = Concurrent::ScheduledTask.execute(delay) do
        begin
          block.call
        rescue StandardError => e
          warn "[Timer] Callback error: #{e.message}"
        end
      end
      @tasks << task
      task
    end

    # Schedule a repeating callback
    # @param interval [Numeric] Interval in seconds
    # @param block [Proc] The callback to execute
    # @return [RepeatingTask]
    def every(interval, &block)
      task = RepeatingTask.new(interval, &block)
      task.start
      @tasks << task
      task
    end

    # Cancel all scheduled tasks
    def cancel_all
      @tasks.each do |task|
        if task.respond_to?(:cancel)
          task.cancel
        elsif task.respond_to?(:stop)
          task.stop
        end
      end
      @tasks.clear
    end

    # Class method to schedule a one-shot callback
    def self.after(delay, &block)
      default.after(delay, &block)
    end

    # Class method to schedule a repeating callback
    def self.every(interval, &block)
      default.every(interval, &block)
    end

    # Default timer instance
    def self.default
      @default ||= new
    end

    # Reset default timer (cancel all tasks)
    def self.reset
      @default&.cancel_all
      @default = nil
    end
  end

  # A repeating scheduled task
  class RepeatingTask
    attr_reader :interval

    def initialize(interval, &block)
      @interval = interval
      @block = block
      @running = false
      @task = nil
    end

    def start
      @running = true
      schedule_next
      self
    end

    def stop
      @running = false
      @task&.cancel
      @task = nil
      self
    end

    alias cancel stop

    def running?
      @running
    end

    private

    def schedule_next
      return unless @running

      @task = Concurrent::ScheduledTask.execute(@interval) do
        execute_callback
      end
    end

    def execute_callback
      return unless @running

      begin
        @block.call
      rescue StandardError => e
        warn "[Timer] Callback error: #{e.message}"
      end

      schedule_next if @running
    end
  end
end
