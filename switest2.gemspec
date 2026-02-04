# frozen_string_literal: true

require_relative "lib/switest2/version"

Gem::Specification.new do |spec|
  spec.name = "switest2"
  spec.version = Switest2::VERSION
  spec.authors = ["Firmafon"]
  spec.email = ["dev@firmafon.dk"]

  spec.summary = "Functional testing for voice applications via FreeSWITCH ESL"
  spec.description = "Switest2 lets you write functional tests for your voice applications, " \
                     "using direct ESL (Event Socket Library) communication with FreeSWITCH."
  spec.homepage = "https://github.com/firmafon/switest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/**/*") + %w[README.md LICENSE]
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "minitest", ">= 5.5", "< 7.0"
end
