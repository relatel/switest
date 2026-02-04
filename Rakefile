#!/usr/bin/env rake

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib" << "test"
  t.test_files = Dir.glob("test/unit/switest2/**/*_test.rb")
  t.verbose = true
  t.warning = false
end

Rake::TestTask.new(:integration) do |t|
  t.libs << "lib" << "test"
  t.test_files = Dir.glob("test/integration/**/*_test.rb")
  t.verbose = true
  t.warning = false
end

Rake::TestTask.new(:all) do |t|
  t.libs << "lib" << "test"
  t.test_files = Dir.glob("test/unit/switest2/**/*_test.rb") +
                 Dir.glob("test/integration/**/*_test.rb")
  t.verbose = true
  t.warning = false
end

task default: :test
