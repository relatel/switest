# encoding: utf-8

$LOAD_PATH.unshift("lib")

Bundler.require(:default, :test) if defined?(Bundler)

require "minitest/autorun"
require "timeout"
require "switest"

class Minitest::Test
  include Switest
end
