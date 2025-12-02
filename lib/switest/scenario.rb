# frozen_string_literal: true

require "minitest"

module Switest
  # Base class for Switest test scenarios.
  # Provides setup/teardown for Rayo connection and test assertions.
  class Scenario < Minitest::Test
    def setup
      Switest.connection.start
      Switest.reset
    end

    def teardown
      Switest.connection.cleanup
    end

    # Assert that an agent received a call
    def assert_call(agent, timeout: 5)
      agent.wait_for_call(timeout: timeout)
      assert(agent.call, "#{agent} did not have a call")
    end

    # Assert that an agent did not receive a call
    def assert_no_call(agent, timeout: 5)
      agent.wait_for_call(timeout: timeout)
      assert_nil(agent.call, "#{agent} did have a call")
    end

    # Assert that an agent's call was hung up
    def assert_hungup(agent, timeout: 5)
      agent.wait_for_end(timeout: timeout)
      assert(agent.call&.end_reason, "#{agent} was not ended")
    end

    # Assert that an agent's call was not hung up
    def assert_not_hungup(agent, timeout: 5)
      assert_nil(agent.call&.end_reason, "#{agent} was hungup")
    end

    # Assert that an agent's call was answered
    def assert_answered(agent, timeout: 5)
      agent.wait_for_answer(timeout: timeout)
      assert(agent.call&.answered?, "#{agent} was not answered")
    end

    # Assert that an agent received specific DTMF digits
    # @param agent [Agent] The agent to check
    # @param dtmf [String] The expected DTMF digits
    # @param timeout [Numeric] Timeout in seconds
    def assert_dtmf(agent, dtmf, timeout: 5)
      result = agent.receive_dtmf(max_digits: dtmf.size, timeout: timeout)
      assert_equal(dtmf, result, "Expected DTMF '#{dtmf}' but got '#{result}'")
    end

    # Helper to sleep for a duration (use sparingly in tests)
    def wait(seconds)
      sleep(seconds)
    end

    # Get the timer instance for scheduling callbacks
    # @return [Timer]
    def timer
      @timer ||= Timer.new
    end
  end
end
