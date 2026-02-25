# frozen_string_literal: true

require_relative "lib/switest/version"

Gem::Specification.new do |spec|
  spec.name = "switest"
  spec.version = Switest::VERSION
  spec.authors = ["Relatel A/S", "Henrik Hauge Bjørnskov"]
  spec.email = ["teknik@relatel.dk"]

  spec.summary = "Functional testing for voice applications via FreeSWITCH ESL"
  spec.description = "Switest lets you write functional tests for your voice applications, " \
                     "using direct ESL (Event Socket Library) communication with FreeSWITCH."

  spec.homepage = "https://github.com/relatel/switest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/switest/**/*") + %w[lib/switest.rb README.md LICENSE]
  spec.require_paths = ["lib"]

  spec.add_dependency "librevox", "~> 1.0"
  spec.add_dependency "minitest", ">= 5.5", "< 7.0"
end
