# encoding: utf-8

require "test_helper"

class Switest::AgentTest < Minitest::Test
  def setup
    super
    Switest.reset
  end

  def test_listen_for_call_without_conditions
    agent = Agent.new
    agent.listen_for_call

    call = ::Adhearsion::Call.new
    Switest.events.trigger_handler(:inbound_call, call)

    assert_equal call, agent.call
  end

  def test_with_conditions_matching
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    offer = Punchblock::Event::Offer.new(to: "71999999")
    call = ::Adhearsion::Call.new(offer)
    Switest.events.trigger_handler(:inbound_call, call)

    assert_equal call, agent.call
  end

  def test_with_conditions_not_matching
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    offer = Punchblock::Event::Offer.new(to: "22334455")
    call = ::Adhearsion::Call.new(offer)
    Switest.events.trigger_handler(:inbound_call, call)

    assert_nil agent.call
  end

  def test_wait_for_call_success
    agent = Agent.new
    agent.listen_for_call(to: /71999999/)

    offer = Punchblock::Event::Offer.new(to: "71999999")
    call = ::Adhearsion::Call.new(offer)

    Thread.new {
      sleep 1
      Switest.events.trigger_handler(:inbound_call, call)
    }

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
    agent.call = ::Adhearsion::OutboundCall.new

    Thread.new {
      sleep 1
      agent.call << Punchblock::Event::Answered.new
    }

    Timeout.timeout(2) do
      agent.wait_for_answer
    end
  end

  def test_wait_for_end
    agent = Agent.new
    agent.call = ::Adhearsion::OutboundCall.new

    Thread.new {
      sleep 1
      agent.call << Punchblock::Event::End.new
    }

    Timeout.timeout(2) do
      agent.wait_for_end
    end
  end
end
