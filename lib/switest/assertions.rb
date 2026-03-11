# frozen_string_literal: true

module Switest
  module Assertions
    def assert_call(agent, timeout: 5)
      success = agent.wait_for_call(timeout: timeout)
      assert success, "Expected agent to receive a call within #{timeout} seconds"
    end

    def assert_no_call(agent, timeout: 2)
      sleep timeout
      refute agent.call?, "Expected agent to not have received a call"
    end

    def assert_answered(agent, timeout: 5)
      assert agent.call?, "Agent has no call"
      success = agent.wait_for_answer(timeout: timeout)
      assert success, "Expected call to be answered within #{timeout} seconds"
    end

    def assert_hungup(agent, timeout: 5)
      assert agent.call?, "Agent has no call"
      success = agent.wait_for_end(timeout: timeout)
      assert success, "Expected call to be hung up within #{timeout} seconds"
    end

    def assert_not_hungup(agent, timeout: 2)
      assert agent.call?, "Agent has no call"
      sleep timeout
      refute agent.ended?, "Expected call to still be active"
    end

    def assert_dtmf(agent, expected_dtmf, timeout: 5, after: 1, &block)
      assert agent.call?, "Agent has no call"

      if block
        agent.flush_dtmf
        Async do
          sleep after
          block.call
        end
        received = agent.receive_dtmf(count: expected_dtmf.length, timeout: timeout + after)
      else
        received = agent.receive_dtmf(count: expected_dtmf.length, timeout: timeout)
      end

      assert_equal expected_dtmf, received, "Expected DTMF '#{expected_dtmf}' but received '#{received}'"
    end

  end
end
