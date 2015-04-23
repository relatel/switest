Gem::Specification.new do |s|
  s.name     = "switest"
  s.version  = "0.1"
  s.date     = "2015-04-23"
  s.summary  = "Switest"
  s.email    = "hv@firmafon.dk"
  s.homepage = "http://github.com/firmafon/switest"
  s.description = "Functional testing for voice applications"
  s.authors  = ["Harry Vangberg"]
  s.files    = Dir["lib/**/*"] + %w(README.md)
  s.test_files = Dir["test/**/*"]

  s.add_dependency "adhearsion", "~> 2.6"
  s.add_dependency "adhearsion-asr", "~> 1.2"
  s.add_dependency "punchblock", "~> 2.6"
  s.add_dependency "timers", "~> 1.1"
  s.add_dependency "minitest", "~> 5.5.0"
end
