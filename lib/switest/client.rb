# frozen_string_literal: true

require "securerandom"
require "async/barrier"
require "async/promise"
require_relative "from_parser"

module Switest
  class Client
    attr_reader :calls

    def initialize
      @calls = {}
      @offer_handlers = []
      @session = nil
      @client_task = nil
    end

    def start
      config = Switest.configuration

      # Configure Session class with client state
      Session.call_registry = @calls
      Session.offer_handler = method(:handle_inbound_offer)
      Session.connection_promise = Async::Promise.new

      @client_task = Async do
        Librevox::Client.start(Session, host: config.host, port: config.port, auth: config.password)
      end

      # Wait for the session to be established
      session = Async::Task.current.with_timeout(config.default_timeout) do
        Session.connection_promise.wait
      end

      @session = session

      self
    rescue Async::TimeoutError
      @client_task&.stop
      @client_task = nil
      raise Switest::ConnectionError, "Timed out connecting to FreeSWITCH"
    end

    def stop
      hangup_all
      @client_task&.stop
      @client_task = nil
      @session = nil
      @calls.clear
      Session.call_registry = nil
      Session.offer_handler = nil
      Session.connection_promise = nil
    end

    def connected?
      !@session.nil?
    end

    def hangup_all(cause: "NORMAL_CLEARING", timeout: 5)
      active = @calls.values.reject(&:ended?)

      Async::Task.current.with_timeout(timeout) do
        barrier = Async::Barrier.new
        active.each do |call|
          barrier.async do
            call.hangup(cause) rescue nil
            call.wait_for_end(timeout: timeout) unless call.ended?
          end
        end
        barrier.wait
      end
    rescue Async::TimeoutError
      # Best-effort cleanup; don't block teardown
    end

    def dial(to:, from: nil, timeout: nil, headers: {})
      uuid = SecureRandom.uuid

      vars = {
        origination_uuid: uuid,
        return_ring_ready: true
      }
      vars.merge!(FromParser.parse(from)) if from
      vars[:originate_timeout] = timeout if timeout

      var_string = Escaper.build_var_string(vars, headers)

      call = Call.new(
        id: uuid,
        direction: :outbound,
        to: to,
        from: from,
        headers: headers,
        session: @session
      )
      @calls[uuid] = call

      begin
        @session.bgapi("originate #{var_string}#{to} &park()")
      rescue
        @calls.delete(uuid)
        raise
      end

      call
    end

    def on_offer(&block)
      @offer_handlers << block
    end

    def active_calls
      @calls.select { |_k, v| v.alive? }
    end

    private

    def handle_inbound_offer(event)
      uuid = event.content[:unique_id]
      data = event.content

      call = Call.new(
        id: uuid,
        direction: :inbound,
        to: data[:caller_destination_number],
        from: data[:caller_caller_id_number],
        headers: data,
        session: @session
      )
      call.handle_callstate("RINGING")
      @calls[uuid] = call

      fire_offer(call)
    end

    def fire_offer(call)
      @offer_handlers.each { |h| h.call(call) }
    end
  end
end
