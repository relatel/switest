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

    def assert_hangup_reason(reason, agent)
      assert agent.call?, "Agent has no call"
      assert_equal reason, agent.call.end_reason,
        "Expected hangup reason '#{reason}' but got '#{agent.call.end_reason}'"
    end

    def assert_sip_hangup_code(code, agent)
      assert agent.call?, "Agent has no call"
      actual = agent.call.headers[:variable_sip_term_status]
      assert_equal code.to_s, actual,
        "Expected SIP hangup code '#{code}' but got '#{actual}'"
    end

    def assert_from(number, agent)
      assert agent.call?, "Agent has no call"
      actual = agent.call.headers[:variable_sip_from_user]
      assert_equal number, actual,
        "Expected SIP From '#{number}' but got '#{actual}'"
    end

    def assert_from_display(name, agent)
      assert agent.call?, "Agent has no call"
      actual = agent.call.headers[:variable_sip_from_display]
      assert_equal name, actual,
        "Expected SIP From display '#{name}' but got '#{actual}'"
    end

    def assert_asserted_identity(number, agent)
      assert agent.call?, "Agent has no call"
      actual = agent.call.headers[:variable_sip_h_p_asserted_identity]
      assert_includes actual.to_s, number,
        "Expected P-Asserted-Identity to contain '#{number}' but got '#{actual}'"
    end

    def assert_diversion(number, params, agent)
      assert agent.call?, "Agent has no call"
      actual = agent.call.headers[:variable_sip_h_diversion]
      assert_includes actual.to_s, number,
        "Expected Diversion to contain '#{number}' but got '#{actual}'"
      params.each do |key, value|
        assert_includes actual.to_s, "#{key}=#{value}",
          "Expected Diversion to contain '#{key}=#{value}' but got '#{actual}'"
      end
    end
  end
end
