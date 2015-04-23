# encoding: utf-8

require "test_helper"

class Switest::CallControllerTest < Minitest::Test
  def setup
    super
    Switest.reset
  end

  def test_inbound_call
    call = ::Adhearsion::Call.new

    triggered = false
    Switest.events.register_handler(:inbound_call) do
      triggered = true
    end

    CallController.new(call).run

    assert_equal true, triggered
  end

  def test_outbound_call
    call = ::Adhearsion::OutboundCall.new

    triggered = false
    Switest.events.register_handler(:outbound_call) do
      triggered = true
    end

    CallController.new(call).run

    assert_equal false, triggered
  end
end
