# frozen_string_literal: true
require "bundler/setup"

require "minitest/test_task"
require "bundler/gem_tasks"

Minitest::TestTask.create(:test) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/unit/switest/**/*_test.rb"]
  t.warning = false
end

Minitest::TestTask.create(:integration) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/integration/**/*_test.rb"]
  t.warning = false
  t.verbose = true
end

Minitest::TestTask.create(:scenarios) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/scenarios/**/*_scenario.rb"]
  t.warning = false
  t.verbose = true
end

Minitest::TestTask.create(:all) do |t|
  t.libs << "lib" << "test"
  t.test_globs = ["test/unit/switest/**/*_test.rb", "test/integration/**/*_test.rb", "test/scenarios/**/*_scenario.rb"]
  t.warning = false
end

task :version do
  require_relative "lib/switest/version"
  print Switest::VERSION
end

task default: :test
