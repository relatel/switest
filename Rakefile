#!/usr/bin/env rake
# frozen_string_literal: true

require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/unit/switest2/**/*_test.rb"]
  t.warning = false
end

Minitest::TestTask.create(:integration) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/integration/**/*_test.rb"]
  t.warning = false
  t.verbose = true
end

Minitest::TestTask.create(:all) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/unit/switest2/**/*_test.rb", "test/integration/**/*_test.rb"]
  t.warning = false
end

task :version do
  require_relative "lib/switest2/version"
  print Switest2::VERSION
end

task default: :test
