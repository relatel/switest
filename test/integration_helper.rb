# frozen_string_literal: true

require "switest"

# Configure FreeSWITCH connection from environment
Switest.configure do |config|
  config.host = ENV.fetch("FREESWITCH_HOST", "127.0.0.1")
  config.port = ENV.fetch("FREESWITCH_PORT", 8021).to_i
  config.password = ENV.fetch("FREESWITCH_PASSWORD", "ClueCon")
end
