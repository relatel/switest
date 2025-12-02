Gem::Specification.new do |s|
  s.name     = "switest"
  s.version  = "0.2"
  s.date     = "2025-12-02"
  s.summary  = "Switest"
  s.email    = "relatel@firmafon.dk"
  s.homepage = "http://github.com/relatel/switest"
  s.description = "Functional testing for voice applications using FreeSWITCH ESL"
  s.authors  = ["Harry Vangberg", "Relatel"]
  s.files    = Dir["lib/**/*"] + %w(README.md)
  s.test_files = Dir["test/**/*"]

  s.add_dependency "concurrent-ruby", "~> 1.2"
  s.add_dependency "logger", "~> 1.6"
  s.add_dependency "minitest", ">= 5.5", "< 6.0"

  s.required_ruby_version = ">= 2.6", "< 4.0"
end
