Gem::Specification.new do |s|
  s.name     = "switest"
  s.version  = "0.1"
  s.date     = "2015-04-23"
  s.summary  = "Switest"
  s.email    = "relatel@firmafon.dk"
  s.homepage = "http://github.com/relatel/switest"
  s.description = "Functional testing for voice applications"
  s.authors  = ["Harry Vangberg", "Relatel"]
  s.files    = Dir["lib/**/*"] + %w(README.md)
  s.test_files = Dir["test/**/*"]

  s.add_dependency "blather", "~> 2.0"
  s.add_dependency "concurrent-ruby", "~> 1.2"
  s.add_dependency "minitest", ">= 5.5", "< 6.0"

  s.required_ruby_version = ">= 3.0"
end
