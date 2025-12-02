# frozen_string_literal: true

require "test_helper"

class Switest::AgentTest < Minitest::Test
  def setup
    super
    Switest.reset
  end

  def test_listen_for_call_without_conditions
    agent = Agent.new
    agent.listen_for_call

    call = create_mock_call
    Switest.events.trigger(:inbound_call, call)

    assert_equal call, agent.call
  end

  def test_with_conditions_matching
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    call = create_mock_call(to: "71999999")
    Switest.events.trigger(:inbound_call, call)

    assert_equal call, agent.call
  end

  def test_with_conditions_not_matching
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    call = create_mock_call(to: "22334455")
    Switest.events.trigger(:inbound_call, call)

    assert_nil agent.call
  end

  def test_wait_for_call_success
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    call = create_mock_call(to: "71999999")

    Thread.new do
      sleep 0.5
      Switest.events.trigger(:inbound_call, call)
    end

    Timeout.timeout(2) do
      agent.wait_for_call
      assert_equal call, agent.call
    end
  end

  def test_wait_for_call_timeout
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    Timeout.timeout(2) do
      agent.wait_for_call(timeout: 1)
      assert_nil agent.call
    end
  end

  def test_wait_for_answer
    agent = Agent.new
    agent.call = create_mock_call

    Thread.new do
      sleep 0.5
      agent.call.simulate_answer
    end

    Timeout.timeout(2) do
      result = agent.wait_for_answer
      assert result
      assert agent.call.answered?
    end
  end

  def test_wait_for_end
    agent = Agent.new
    agent.call = create_mock_call
    agent.call.simulate_answer # First answer the call

    Thread.new do
      sleep 0.5
      agent.call.simulate_end(:hangup)
    end

    Timeout.timeout(2) do
      result = agent.wait_for_end
      assert result
      assert agent.call.ended?
    end
  end

  private

  def create_mock_call(to: nil, from: nil, headers: {})
    mock_client = Switest::ESL::MockClient.new
    Switest::ESL::MockCall.new(mock_client, to: to, from: from, headers: headers)
  end
end
