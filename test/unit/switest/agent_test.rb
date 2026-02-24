# frozen_string_literal: true

require_relative "../../test_helper"

class Switest::AgentTest < Minitest::Test
  def setup
    @events = Switest::Events.new
    @connection = Switest::ESL::MockConnection.new
    @client = Switest::ESL::Client.new(@connection)
    Switest::Agent.setup(@client, @events)
  end

  def teardown
    Switest::Agent.teardown
  end

  def test_listen_for_call_without_conditions
    agent = Switest::Agent.listen_for_call

    call = Switest::ESL::Call.new(
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
    agent = Switest::Agent.listen_for_call(to: /71999999/)

    call = Switest::ESL::Call.new(
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
    agent = Switest::Agent.listen_for_call(to: /71999999/)

    call = Switest::ESL::Call.new(
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
    agent = Switest::Agent.listen_for_call(to: /71999999/)

    call = Switest::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999",
      from: "12345"
    )

    Async do
      sleep 0.5
      @events.emit(:offer, { to: call.to, from: call.from, call: call })
    end

    result = agent.wait_for_call(timeout: 2)
    assert result
    assert_equal call, agent.call
  end

  def test_wait_for_call_timeout
    agent = Switest::Agent.listen_for_call(to: /71999999/)

    result = agent.wait_for_call(timeout: 0.5)
    refute result
    assert_nil agent.call
  end

  def test_wait_for_answer
    call = Switest::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound,
      to: "71999999"
    )
    agent = Switest::Agent.new(call)

    Async do
      sleep 0.5
      call.handle_answer
    end

    result = agent.wait_for_answer(timeout: 2)
    assert result
    assert agent.answered?
  end

  def test_wait_for_end
    call = Switest::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :outbound,
      to: "71999999"
    )
    agent = Switest::Agent.new(call)

    Async do
      sleep 0.5
      call.handle_hangup("NORMAL_CLEARING")
    end

    result = agent.wait_for_end(timeout: 2)
    assert result
    assert agent.ended?
  end

  def test_answer_sends_command
    call = Switest::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999"
    )
    agent = Switest::Agent.new(call)

    agent.answer(wait: false)

    assert @connection.commands_sent.any? { |cmd| cmd.include?("answer") }
  end

  def test_hangup_sends_command
    call = Switest::ESL::Call.new(
      id: "test-uuid",
      connection: @connection,
      direction: :inbound,
      to: "71999999"
    )
    agent = Switest::Agent.new(call)

    agent.hangup(wait: false)

    assert @connection.commands_sent.any? { |cmd| cmd.include?("hangup") }
  end
end
