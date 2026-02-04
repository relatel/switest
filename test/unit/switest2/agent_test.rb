# frozen_string_literal: true

require_relative "../../switest2_test_helper"

class Switest2::AgentTest < Minitest::Test
  def setup
    @events = Switest2::Events.new
    @connection = Switest2::ESL::MockConnection.new
    @client = Switest2::ESL::Client.new(@connection)
    Switest2::Agent.setup(@client, @events)
  end

  def teardown
    Switest2::Agent.teardown
  end

  def test_listen_for_call_without_conditions
    agent = Switest2::Agent.listen_for_call

    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999",
      from: "12345"
    )
    @events.emit(:offer, { to: call.to, from: call.from, call: call })

    assert_equal call, agent.call
  end

  def test_with_conditions_matching
    agent = Switest2::Agent.listen_for_call(to: /71999999/)

    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999",
      from: "12345"
    )
    @events.emit(:offer, { to: call.to, from: call.from, call: call })

    assert_equal call, agent.call
  end

  def test_with_conditions_not_matching
    agent = Switest2::Agent.listen_for_call(to: /71999999/)

    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "22334455",
      from: "12345"
    )
    @events.emit(:offer, { to: call.to, from: call.from, call: call })

    assert_nil agent.call
  end

  def test_wait_for_call_success
    agent = Switest2::Agent.listen_for_call(to: /71999999/)

    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999",
      from: "12345"
    )

    Thread.new {
      sleep 0.5
      @events.emit(:offer, { to: call.to, from: call.from, call: call })
    }

    Timeout.timeout(2) do
      result = agent.wait_for_call(timeout: 2)
      assert result
      assert_equal call, agent.call
    end
  end

  def test_wait_for_call_timeout
    agent = Switest2::Agent.listen_for_call(to: /71999999/)

    Timeout.timeout(2) do
      result = agent.wait_for_call(timeout: 0.5)
      refute result
      assert_nil agent.call
    end
  end

  def test_wait_for_answer
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound,
      to: "71999999"
    )
    agent = Switest2::Agent.new(call)

    Thread.new {
      sleep 0.5
      call.handle_answer
    }

    Timeout.timeout(2) do
      result = agent.wait_for_answer(timeout: 2)
      assert result
      assert agent.answered?
    end
  end

  def test_wait_for_end
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound,
      to: "71999999"
    )
    agent = Switest2::Agent.new(call)

    Thread.new {
      sleep 0.5
      call.handle_hangup("NORMAL_CLEARING")
    }

    Timeout.timeout(2) do
      result = agent.wait_for_end(timeout: 2)
      assert result
      assert agent.ended?
    end
  end

  def test_answer_sends_command
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999"
    )
    agent = Switest2::Agent.new(call)

    agent.answer

    assert @connection.commands_sent.any? { |cmd| cmd.include?("answer") }
  end

  def test_hangup_sends_command
    call = Switest2::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999"
    )
    agent = Switest2::Agent.new(call)

    agent.hangup

    assert @connection.commands_sent.any? { |cmd| cmd.include?("hangup") }
  end
end
