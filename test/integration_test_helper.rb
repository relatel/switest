# frozen_string_literal: true

$LOAD_PATH.unshift("lib")

require "bundler/setup" if defined?(Bundler)
require "minitest"
require "switest2"

# Configure FreeSWITCH connection from environment
Switest2.configure do |config|
  config.host = ENV.fetch("FREESWITCH_HOST", "127.0.0.1")
  config.port = ENV.fetch("FREESWITCH_PORT", 8021).to_i
  config.password = ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
end
