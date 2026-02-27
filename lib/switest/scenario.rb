# frozen_string_literal: true

require "minitest/test"
require "async"

module Switest
  class Scenario < Minitest::Test
    include Assertions

    # Make Agent accessible to subclasses
    Agent = Switest::Agent

    # Run each test inside an async reactor so that fibers, conditions,
    # and async I/O work transparently for users extending Scenario.
    def run(...)
      Sync { super }
    end

    def setup
      @events = Events.new
      @client = Client.new
      @client.start

      # Route inbound calls through events system
      @client.on_offer do |call|
        @events.emit(:offer, {
          to: call.to,
          from: call.from,
          call: call,
          headers: call.headers,
          profile: call.headers[:variable_sofia_profile_name]
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
  end
end
