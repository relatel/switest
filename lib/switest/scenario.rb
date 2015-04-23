# encoding: utf-8

require "minitest"

module Switest
  class Scenario < Minitest::Test
    def setup
      Switest.adhearsion.start
      Switest.reset
    end

    def teardown
      Switest.adhearsion.cleanup
    end

    def timer
      @_timer ||= Switest::Timer.new
    end

    def assert_call(agent, timeout: 5)
      agent.wait_for_call(timeout: timeout)
      assert(agent.call, "#{agent} did not have a call")
    end

    def assert_no_call(agent, timeout: 5)
      agent.wait_for_call(timeout: timeout)
      assert_nil(agent.call, "#{agent} did have a call")
    end

    def assert_hungup(agent, timeout: 5)
      agent.wait_for_end(timeout: timeout)
      assert(agent.call.end_reason, "#{agent} was not ended")
    end

    def assert_not_hungup(agent, timeout: 5)
      assert_nil(agent.call.end_reason, "#{agent} was hungup")
    end

    def assert_dtmf(agent, dtmf, timeout: 5)
      result = agent.receive_dtmf(
        timeout: timeout,
        limit: dtmf.size
      )
      assert_equal(dtmf, result)
    end
  end
end
