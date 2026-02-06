# frozen_string_literal: true

require "minitest/test"

module Switest
  class Scenario < Minitest::Test
    # Make Agent accessible to subclasses
    Agent = Switest::Agent

    def setup
      @events = Events.new
      @client = ESL::Client.new
      @client.start

      # Route inbound calls through events system
      @client.on_offer do |call|
        @events.emit(:offer, {
          to: call.to,
          from: call.from,
          call: call,
          headers: call.headers,
          profile: call.headers["variable_sofia_profile_name"]
        })
      end

      Agent.setup(@client, @events)
    end

    def teardown
      Agent.teardown
      @client&.stop
    end

    # Hangup all active calls and wait for them to end.
    # Useful when tests need all legs hung up before proceeding (e.g., for CDR writes).
    def hangup_all(cause: "NORMAL_CLEARING", timeout: 5)
      @client&.hangup_all(cause: cause, timeout: timeout)
    end

    # Assertions
    def assert_call(agent, timeout: 5)
      success = agent.wait_for_call(timeout: timeout)
      assert success, "Expected agent to receive a call within #{timeout} seconds"
    end

    def assert_no_call(agent, timeout: 2)
      sleep timeout
      refute agent.call?, "Expected agent to not have received a call"
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

    def assert_dtmf(agent, expected_dtmf, timeout: 5)
      assert agent.call?, "Agent has no call"
      received = agent.receive_dtmf(count: expected_dtmf.length, timeout: timeout)
      assert_equal expected_dtmf, received, "Expected DTMF '#{expected_dtmf}' but received '#{received}'"
    end
  end
end
