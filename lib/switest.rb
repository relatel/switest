# encoding: utf-8

Thread.abort_on_exception = true

require "switest/adhearsion"
require "switest/agent"
require "switest/call_controller"
require "switest/events"
require "switest/scenario"
require "switest/timer"

module Switest
  def self.adhearsion
    @adhearsion ||= Adhearsion.new
  end

  def self.calls
    @calls ||= Calls.new
  end

  def self.events
    @events ||= Events.new
  end

  def self.logger
    @logger ||= logger!
  end

  def self.logger!
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    logger
  end

  def self.reset
    @events = nil
  end
end
